//! Reverse proxy for the home lab, built on Pingora.
//!
//! The job this solves is not load balancing; it is that two very different
//! kinds of traffic arrive at the same set of backends and must not be treated
//! alike:
//!
//!   * Traffic over the Tailscale mesh is already authenticated and encrypted by
//!     WireGuard before it reaches us. Anyone on the tailnet is someone who was
//!     deliberately invited, so they get everything.
//!
//!   * Traffic out of the Cloudflare tunnel is the public internet wearing a
//!     local return address. It is allowed to reach only the services that were
//!     explicitly published, and today that list is empty -- so it gets a 404,
//!     which is also the honest answer: from the public side those hostnames do
//!     not exist.
//!
//! The two are told apart by which socket the connection arrived on, not by a
//! header, because headers are attacker-controlled and the listening socket is
//! not. cloudflared is configured to talk to a loopback-only port; nothing else
//! can reach it.
//!
//! TLS terminates here for the tailnet side, with a wildcard certificate issued
//! by Let's Encrypt over the DNS-01 challenge. WireGuard already encrypts that
//! leg, so this is not about the wire -- it is about the browser. Vaultwarden's
//! web vault needs WebCrypto, which browsers expose only in a secure context; a
//! public parent domain with HSTS makes browsers refuse plain HTTP outright; and
//! Nextcloud is told to emit https:// URLs, which have to actually resolve.
//!
//! The tunnel listener stays plain HTTP, and correctly so: Cloudflare terminated
//! TLS at its edge and cloudflared carried it encrypted to loopback. Upstreams
//! are all on 127.0.0.1, where another TLS hop would buy nothing.

use std::collections::HashMap;
use std::net::IpAddr;
use std::sync::Arc;

use async_trait::async_trait;
use pingora::http::ResponseHeader;
use pingora::prelude::*;
use pingora::proxy::{http_proxy_service, ProxyHttp, Session};
use pingora::server::configuration::Opt;
use pingora::server::Server;
use pingora::upstreams::peer::HttpPeer;
use serde::Deserialize;

mod control;
use control::{Action, Control};

/// Rendered by the NixOS module; see services/proxy.nix.
#[derive(Debug, Deserialize)]
struct Config {
    /// TLS socket for traffic arriving over the tailnet (and anything else that
    /// can reach the host). Trust is decided per connection, by source address.
    trusted_listen: String,
    /// Wildcard certificate for the trusted listener, maintained by ACME.
    cert_path: String,
    key_path: String,
    /// Plain socket that answers nothing but a redirect to the TLS one.
    redirect_listen: String,
    /// Loopback socket that cloudflared is pointed at. Plain HTTP on purpose.
    tunnel_listen: String,
    routes: Vec<Route>,
    /// Optional on/off panel for a single systemd unit.
    #[serde(default)]
    control: Option<ControlConfig>,
}

#[derive(Debug, Deserialize)]
struct ControlConfig {
    /// Hostname the panel answers on. Reachable from both doors, since the
    /// point of it is to work from away from home.
    host: String,
    /// File holding the token. A file and not an inline value because the
    /// config itself is a world-readable path in the Nix store.
    token_file: String,
    /// systemd unit to start and stop.
    unit: String,
    /// UDP port the service binds once it is genuinely usable. Without it, an
    /// active unit counts as running -- which for valheim would claim the
    /// server is up minutes before it answers.
    #[serde(default)]
    ready_port: Option<u16>,
}

#[derive(Debug, Deserialize, Clone)]
struct Route {
    /// Hostname to match, compared case-insensitively and without the port.
    host: String,
    /// `ip:port` of the backend.
    upstream: String,
    /// Whether this service may be reached from the Cloudflare tunnel.
    #[serde(default)]
    public: bool,
}

/// Which door a request came through.
#[derive(Clone, Copy, PartialEq)]
enum Door {
    /// The TLS socket the tailnet reaches. Still verified per connection.
    Trusted,
    /// The loopback socket cloudflared talks to.
    Tunnel,
    /// Plain HTTP, answers only with a redirect to the TLS listener.
    Redirect,
}

struct Gateway {
    door: Door,
    routes: Arc<HashMap<String, Route>>,
    control: Option<Arc<Control>>,
}

/// Tailscale hands out addresses from the CGNAT range reserved in RFC 6598.
/// A packet with one of these as its source reached us over the WireGuard
/// interface; nothing routable on the LAN or the internet carries it.
fn is_tailnet(ip: IpAddr) -> bool {
    match ip {
        IpAddr::V4(v4) => v4.octets()[0] == 100 && (64..128).contains(&v4.octets()[1]),
        // Tailscale's IPv6 range.
        IpAddr::V6(v6) => v6.segments()[0] == 0xfd7a,
    }
}

fn client_ip(session: &Session) -> Option<IpAddr> {
    session
        .client_addr()
        .and_then(|addr| addr.as_inet())
        .map(|inet| inet.ip())
}

/// Host header, lowercased and stripped of any port.
fn requested_host(session: &Session) -> Option<String> {
    let req = session.req_header();

    // HTTP/2 puts the authority in the URI; HTTP/1.1 uses the Host header.
    if let Some(authority) = req.uri.host() {
        return Some(authority.to_ascii_lowercase());
    }

    req.headers
        .get(http::header::HOST)
        .and_then(|value| value.to_str().ok())
        .map(|value| {
            value
                .split(':')
                .next()
                .unwrap_or(value)
                .trim()
                .to_ascii_lowercase()
        })
}

impl Gateway {
    /// Resolve a request to a backend, or to nothing.
    ///
    /// Returning None is not an error condition to be logged loudly: for the
    /// tunnel door it is the normal case for every hostname that has not been
    /// published.
    fn resolve(&self, session: &Session) -> Option<Route> {
        let host = requested_host(session)?;
        let route = self.routes.get(&host)?;

        let trusted = match self.door {
            // The tunnel door never grants trust, whatever the source address
            // says -- cloudflared connects from loopback, which is not
            // distinguishable from any other local process.
            Door::Tunnel | Door::Redirect => false,
            Door::Trusted => client_ip(session).is_some_and(is_tailnet),
        };

        if trusted || route.public {
            Some(route.clone())
        } else {
            None
        }
    }
}

pub struct Ctx {
    route: Option<Route>,
}

/// Serve the control endpoint.
///
/// Returns Ok(None) when the request was not for the panel after all, so the
/// caller falls through to normal routing and an unknown path on this hostname
/// ends up indistinguishable from an unknown hostname anywhere else.
async fn handle_control(session: &mut Session, control: &Control) -> Result<Option<bool>> {
    let path = session.req_header().uri.path().to_string();
    let method = session.req_header().method.clone();

    let Some(action) = control.resolve(&path).await else {
        return Ok(None);
    };

    // Anything that changes state is a POST. A GET that starts a server would
    // fire on a link preview or a prefetch, which is exactly what the panel
    // exists to avoid.
    let mutating = matches!(action, Action::Start | Action::Stop);
    if mutating && method != http::Method::POST {
        return Ok(None);
    }

    let (status, content_type, body) = match action {
        Action::Panel => {
            let token = path.trim_start_matches('/').split('/').next().unwrap_or("");
            let html = control::panel_html(token, &control.unit, control.state().await);
            (200, "text/html; charset=utf-8", html)
        }
        Action::Status => {
            let body = format!("{{\"state\":\"{}\"}}", control.state().await.as_str());
            (200, "application/json", body)
        }
        Action::Start | Action::Stop => {
            let verb = if action == Action::Start { "start" } else { "stop" };
            let ok = control.run(verb).await;
            let body = format!("{{\"accepted\":{ok}}}");
            (if ok { 202 } else { 500 }, "application/json", body)
        }
    };

    let mut header = ResponseHeader::build(status, None)?;
    header.insert_header("content-type", content_type)?;
    header.insert_header("content-length", body.len().to_string())?;
    // The token is in the URL, so keep it out of anywhere it could travel on:
    // no caching, and no Referer on any link the page might carry.
    header.insert_header("cache-control", "no-store")?;
    header.insert_header("referrer-policy", "no-referrer")?;
    session.write_response_header(Box::new(header), false).await?;
    session.write_response_body(Some(body.into()), true).await?;

    Ok(Some(true))
}

#[async_trait]
impl ProxyHttp for Gateway {
    type CTX = Ctx;

    fn new_ctx(&self) -> Self::CTX {
        Ctx { route: None }
    }

    async fn request_filter(&self, session: &mut Session, ctx: &mut Self::CTX) -> Result<bool> {
        // The plain-HTTP door never proxies anything; it exists so that a
        // browser typing the bare hostname lands on TLS instead of a refused
        // connection.
        if self.door == Door::Redirect {
            let host = requested_host(session).unwrap_or_default();
            let target = session
                .req_header()
                .uri
                .path_and_query()
                .map(|pq| pq.as_str())
                .unwrap_or("/");

            let mut header = ResponseHeader::build(301, None)?;
            header.insert_header("location", format!("https://{host}{target}"))?;
            header.insert_header("content-length", "0")?;
            session
                .write_response_header(Box::new(header), true)
                .await?;
            return Ok(true);
        }

        // The control panel is served by the gateway itself, not proxied. It
        // answers on both the trusted and the tunnel door on purpose: switching
        // the server on from outside the house is the entire point.
        if let Some(control) = self.control.as_ref() {
            if requested_host(session).as_deref() == Some(control.host.as_str()) {
                if let Some(reply) = handle_control(session, control).await? {
                    return Ok(reply);
                }
            }
        }

        ctx.route = self.resolve(session);

        if ctx.route.is_some() {
            return Ok(false);
        }

        // Same answer for "no such hostname" and "not published": a 404 that
        // distinguishes the two would tell a scanner which internal services
        // exist.
        let mut header = ResponseHeader::build(404, None)?;
        header.insert_header("content-length", "0")?;
        header.insert_header("cache-control", "no-store")?;
        session
            .write_response_header(Box::new(header), true)
            .await?;

        Ok(true)
    }

    async fn upstream_peer(&self, _session: &mut Session, ctx: &mut Self::CTX) -> Result<Box<HttpPeer>> {
        // request_filter short-circuits every request that did not resolve, so
        // by here the route is always present.
        let route = ctx
            .route
            .as_ref()
            .expect("request_filter admitted a request with no route");

        Ok(Box::new(HttpPeer::new(
            route.upstream.as_str(),
            false, // no TLS to the backend; everything is on loopback
            String::new(),
        )))
    }

    async fn upstream_request_filter(
        &self,
        session: &mut Session,
        upstream: &mut pingora::http::RequestHeader,
        ctx: &mut Self::CTX,
    ) -> Result<()> {
        let Some(route) = ctx.route.as_ref() else {
            return Ok(());
        };

        // Backends key their own vhosts and redirects off this.
        upstream.insert_header("host", route.host.as_str())?;

        // Everything that reaches a backend arrived over TLS somewhere upstream
        // -- Cloudflare's edge, or WireGuard. Without this Nextcloud and Home
        // Assistant generate http:// URLs and browsers block the mixed content.
        upstream.insert_header("x-forwarded-proto", "https")?;

        if let Some(ip) = client_ip(session) {
            upstream.insert_header("x-forwarded-for", ip.to_string())?;
            upstream.insert_header("x-real-ip", ip.to_string())?;
        }

        Ok(())
    }
}

fn service(
    name: &str,
    door: Door,
    listen: &str,
    tls: Option<(&str, &str)>,
    routes: Arc<HashMap<String, Route>>,
    control: Option<Arc<Control>>,
    server: &Server,
) -> impl pingora::services::Service {
    let mut svc = http_proxy_service(
        &server.configuration,
        Gateway {
            door,
            routes,
            control,
        },
    );

    match tls {
        Some((cert, key)) => {
            // A missing or unreadable certificate is worth failing loudly for:
            // starting without TLS would silently serve the tailnet in the
            // clear, which is the bug this whole listener exists to avoid.
            svc.add_tls(listen, cert, key)
                .unwrap_or_else(|e| panic!("cannot load certificate for {name}: {e}"));
            log::info!("{name} listening on {listen} (TLS)");
        }
        None => {
            svc.add_tcp(listen);
            log::info!("{name} listening on {listen}");
        }
    }

    svc
}

fn main() {
    env_logger::init();

    let path = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "/etc/homelab-gateway/config.json".to_string());

    let raw = std::fs::read_to_string(&path)
        .unwrap_or_else(|e| panic!("cannot read gateway config at {path}: {e}"));
    let config: Config =
        serde_json::from_str(&raw).unwrap_or_else(|e| panic!("invalid gateway config: {e}"));

    let published = config.routes.iter().filter(|r| r.public).count();
    log::info!(
        "{} routes, {} published to the tunnel",
        config.routes.len(),
        published
    );

    let routes: Arc<HashMap<String, Route>> = Arc::new(
        config
            .routes
            .iter()
            .map(|r| (r.host.to_ascii_lowercase(), r.clone()))
            .collect(),
    );

    // The token lives in a file, not in the config: the config is a store path
    // and world-readable, and a token in the URL is already exposed enough.
    let control = config.control.as_ref().map(|c| {
        let token = std::fs::read_to_string(&c.token_file)
            .unwrap_or_else(|e| panic!("cannot read control token at {}: {e}", c.token_file));
        let token = token.trim().to_string();
        assert!(
            token.len() >= 24,
            "control token is too short to sit in a URL: {} chars",
            token.len()
        );
        log::info!("control panel for {} on {}", c.unit, c.host);
        Arc::new(Control::new(
            c.host.clone(),
            token,
            c.unit.clone(),
            c.ready_port,
        ))
    });

    // Opt::default() rather than parsing argv: the only argument is the config
    // path above, and systemd supplies it.
    let mut server = Server::new(Some(Opt::default())).expect("cannot create server");
    server.bootstrap();

    let trusted = service(
        "trusted",
        Door::Trusted,
        &config.trusted_listen,
        Some((&config.cert_path, &config.key_path)),
        routes.clone(),
        control.clone(),
        &server,
    );
    let redirect = service(
        "redirect",
        Door::Redirect,
        &config.redirect_listen,
        None,
        routes.clone(),
        None,
        &server,
    );
    let tunnel = service(
        "tunnel",
        Door::Tunnel,
        &config.tunnel_listen,
        None,
        routes,
        control,
        &server,
    );

    server.add_service(trusted);
    server.add_service(redirect);
    server.add_service(tunnel);
    server.run_forever();
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tailnet_range_is_recognised() {
        assert!(is_tailnet("100.64.0.1".parse().unwrap()));
        assert!(is_tailnet("100.101.102.103".parse().unwrap()));
        assert!(is_tailnet("100.127.255.255".parse().unwrap()));
    }

    #[test]
    fn neighbouring_ranges_are_not_tailnet() {
        // 100.63.x and 100.128.x sit just outside RFC 6598.
        assert!(!is_tailnet("100.63.255.255".parse().unwrap()));
        assert!(!is_tailnet("100.128.0.0".parse().unwrap()));
        // Ordinary private and public addresses.
        assert!(!is_tailnet("192.168.1.50".parse().unwrap()));
        assert!(!is_tailnet("127.0.0.1".parse().unwrap()));
        assert!(!is_tailnet("8.8.8.8".parse().unwrap()));
    }
}

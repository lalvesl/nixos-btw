//! A control panel for one systemd unit, served by the gateway itself.
//!
//! The shape is deliberate. The obvious design -- visit
//! `https://host/<token>/start` and the server starts -- turns a state change
//! into a GET, and GETs get followed by things that are not the user: browser
//! prefetchers, link previews in chat apps, security scanners, the crawler
//! behind a bookmarking service. Pasting that URL into a conversation would be
//! enough to start the server.
//!
//! So the token URL serves an ordinary page, which is safe to fetch any number
//! of times, and the buttons on it POST to the actions. Prefetching the page
//! does nothing.
//!
//! The token is still in the path, as asked, and that has a cost worth knowing:
//! paths appear in proxy logs, in Cloudflare's analytics, in browser history,
//! and in Referer headers on any outbound link. This is a button for turning a
//! game server on, so that trade is reasonable -- but it is why the token is
//! long, why a wrong one is indistinguishable from a missing page, and why
//! guessing is rate limited.

use std::sync::Arc;
use std::time::{Duration, Instant};

use tokio::sync::Mutex;

/// How many rejected tokens before the endpoint stops answering at all, and
/// for how long. A token worth guessing is long enough that this window makes
/// brute force hopeless; the point is to remove the option entirely rather than
/// to slow it down.
const MAX_FAILURES: u32 = 10;
const LOCKOUT: Duration = Duration::from_secs(300);

pub struct Control {
    pub host: String,
    token: Vec<u8>,
    pub unit: String,
    /// UDP port the service binds once it is genuinely usable. Optional: without
    /// it, an active unit is reported as running.
    ready_port: Option<u16>,
    failures: Arc<Mutex<(u32, Instant)>>,
}

/// What the panel shows.
///
/// Three states rather than a boolean, because for this unit "active" and
/// "usable" are minutes apart. Starting valheim.service pulls in
/// valheim-update.service first, which downloads two gigabytes onto an SD card
/// before the game binary is even launched, and then the Unity server spends a
/// while loading the world before it binds its socket. A boolean would report
/// "stopped" through the whole download and then "running" while the server
/// still refuses connections -- wrong in both directions.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum State {
    Stopped,
    Starting,
    Running,
}

impl State {
    pub fn as_str(self) -> &'static str {
        match self {
            State::Stopped => "stopped",
            State::Starting => "starting",
            State::Running => "running",
        }
    }
}

/// Whether anything holds an open UDP socket on this port.
///
/// Read from /proc rather than shelled out to ss: it is world-readable, needs no
/// extra binary in the unit's PATH, and costs one file read. The local address
/// column is "HEXIP:HEXPORT" with the port in four uppercase hex digits.
fn udp_port_bound(port: u16) -> bool {
    let needle = format!(":{port:04X}");
    ["/proc/net/udp", "/proc/net/udp6"].iter().any(|path| {
        std::fs::read_to_string(path)
            .map(|table| {
                table.lines().skip(1).any(|line| {
                    line.split_whitespace()
                        .nth(1)
                        .is_some_and(|local| local.ends_with(&needle))
                })
            })
            .unwrap_or(false)
    })
}

#[derive(Debug, PartialEq)]
pub enum Action {
    /// Render the panel.
    Panel,
    Start,
    Stop,
    Status,
}

impl Control {
    pub fn new(host: String, token: String, unit: String, ready_port: Option<u16>) -> Self {
        Self {
            host,
            token: token.trim().as_bytes().to_vec(),
            unit,
            ready_port,
            failures: Arc::new(Mutex::new((0, Instant::now()))),
        }
    }

    /// Compare without leaking where the first mismatch is. Length is compared
    /// up front and does leak, which is fine: the token length is not secret.
    fn token_matches(&self, candidate: &str) -> bool {
        let candidate = candidate.as_bytes();
        if candidate.len() != self.token.len() {
            return false;
        }
        let mut diff = 0u8;
        for (a, b) in candidate.iter().zip(self.token.iter()) {
            diff |= a ^ b;
        }
        diff == 0
    }

    async fn locked_out(&self) -> bool {
        let mut state = self.failures.lock().await;
        let (count, since) = *state;
        if count >= MAX_FAILURES {
            if since.elapsed() < LOCKOUT {
                return true;
            }
            *state = (0, Instant::now());
        }
        false
    }

    async fn record_failure(&self) {
        let mut state = self.failures.lock().await;
        if state.0 == 0 || state.1.elapsed() >= LOCKOUT {
            *state = (1, Instant::now());
        } else {
            state.0 += 1;
        }
    }

    /// Match a request path against the control endpoint.
    ///
    /// Returns None when this is not a control request at all, so the caller
    /// can fall through to normal routing.
    pub async fn resolve(&self, path: &str) -> Option<Action> {
        if self.locked_out().await {
            log::warn!("control endpoint locked out after repeated bad tokens");
            return None;
        }

        let rest = path.trim_start_matches('/');
        let (candidate, action) = match rest.split_once('/') {
            Some((token, action)) => (token, action.trim_end_matches('/')),
            None => (rest, ""),
        };

        if !self.token_matches(candidate) {
            // Only count attempts that look like someone trying the endpoint,
            // not every unrelated request that lands on this hostname.
            if !candidate.is_empty() {
                self.record_failure().await;
            }
            return None;
        }

        match action {
            "" => Some(Action::Panel),
            "start" => Some(Action::Start),
            "stop" => Some(Action::Stop),
            "status" => Some(Action::Status),
            _ => None,
        }
    }

    /// What systemd says about the unit: "active", "activating", "inactive",
    /// "failed", and so on. Captured as text rather than as an exit status,
    /// because "activating" is the state that matters most here and --quiet
    /// collapses it into failure.
    async fn unit_state(&self) -> String {
        tokio::process::Command::new("systemctl")
            .arg("is-active")
            .arg(&self.unit)
            .output()
            .await
            .map(|out| String::from_utf8_lossy(&out.stdout).trim().to_string())
            .unwrap_or_default()
    }

    /// The state the panel reports.
    pub async fn state(&self) -> State {
        match self.unit_state().await.as_str() {
            "active" => match self.ready_port {
                // The unit is up, but the server only answers once it has
                // opened its socket. Until then it is still starting.
                Some(port) if !udp_port_bound(port) => State::Starting,
                _ => State::Running,
            },
            "activating" | "reloading" => State::Starting,
            _ => State::Stopped,
        }
    }

    /// Start or stop the unit. Returns whether systemd accepted the command.
    pub async fn run(&self, verb: &str) -> bool {
        log::info!("control: {verb} {}", self.unit);
        tokio::process::Command::new("systemctl")
            .arg(verb)
            .arg(&self.unit)
            .status()
            .await
            .map(|s| s.success())
            .unwrap_or(false)
    }
}

/// The panel. Deliberately a single self-contained page with no external
/// references: it is served over a tunnel to a browser that may be on mobile
/// data, and it has to work with no CDN, no fonts and no framework.
pub fn panel_html(token: &str, unit: &str, state: State) -> String {
    format!(
        r#"<!doctype html>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="referrer" content="no-referrer">
<title>{unit}</title>
<style>
  :root {{ color-scheme: light dark; }}
  body {{ font: 16px/1.5 system-ui, sans-serif; margin: 0;
         min-height: 100vh; display: grid; place-items: center; }}
  .card {{ text-align: center; padding: 2rem; }}
  h1 {{ font-size: 1.1rem; font-weight: 600; margin: 0 0 .5rem; }}
  .state {{ font-size: .95rem; margin-bottom: 1.5rem; opacity: .75; }}
  .dot {{ display: inline-block; width: .6em; height: .6em; border-radius: 50%;
          margin-right: .4em; vertical-align: baseline; }}
  .running .dot {{ background: #22a565; }}
  .starting .dot {{ background: #d19a2f; animation: pulse 1.2s ease-in-out infinite; }}
  .stopped .dot {{ background: #9aa0a6; }}
  @keyframes pulse {{ 50% {{ opacity: .25; }} }}
  button {{ font: inherit; padding: .7rem 1.6rem; margin: 0 .25rem;
            border: 1px solid currentColor; border-radius: .5rem;
            background: transparent; color: inherit; cursor: pointer; }}
  button[disabled] {{ opacity: .4; cursor: default; }}
  .note {{ font-size: .8rem; opacity: .6; margin-top: 1rem; min-height: 1.5em; }}
</style>
<div class="card">
  <h1>{unit}</h1>
  <div class="state {state}"><span class="dot"></span><span id="s">{state}</span></div>
  <button id="start">Start</button>
  <button id="stop">Stop</button>
  <p class="note" id="note"></p>
</div>
<script>
  const token = {token_json};
  const NOTE = {{
    starting: 'the first start downloads the server, which takes a while',
    running: '',
    stopped: '',
  }};
  let timer = null;

  const act = async (verb) => {{
    for (const b of document.querySelectorAll('button')) b.disabled = true;
    await fetch('/' + token + '/' + verb, {{ method: 'POST' }});
    // systemd answers once the job is queued, not once the unit settled.
    setTimeout(poll, 1500);
  }};

  const poll = async () => {{
    const r = await fetch('/' + token + '/status');
    const j = await r.json();
    document.querySelector('.state').className = 'state ' + j.state;
    document.getElementById('s').textContent = j.state;
    document.getElementById('note').textContent = NOTE[j.state] || '';
    for (const b of document.querySelectorAll('button')) b.disabled = false;

    // Keep watching while it comes up, so the dot flips on its own once the
    // server actually binds its port. Stop once it has settled.
    clearTimeout(timer);
    if (j.state === 'starting') timer = setTimeout(poll, 5000);
  }};

  document.getElementById('start').onclick = () => act('start');
  document.getElementById('stop').onclick = () => act('stop');
  poll();
</script>
"#,
        unit = unit,
        state = state.as_str(),
        // Through serde so a token with a quote in it cannot break out of the
        // string and into the script.
        token_json = serde_json::to_string(token).unwrap_or_else(|_| "\"\"".into()),
    )
}

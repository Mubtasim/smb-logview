# smb-logview

Read application logs that sit on an SMB (Windows) file share — fast, filtered and live — in the
terminal log viewer [lnav](https://lnav.org).

Made for pod logs that a platform writes to an SMB share (one file per day, e.g. `app.2026-11-26.1.log`),
but it works for any text or JSON log file on a share.

## Why

Opening a log through the file manager (a GVFS/FUSE mount) is slow: the editor reads the file in many
small pieces, each one a network round trip, and a slow share can freeze the editor completely.
These tools instead:

1. **download the whole file in one go** with `smbclient` (with a hard time limit — a slow share gives a
   clear `FAIL`, never a frozen terminal);
2. **refresh it by fetching only the new bytes** (`smbclient reget`), so a live view costs a few KB per refresh;
3. **show it in lnav**: colours by level, jump between errors, search, filters, SQL queries;
4. **hide health-check noise**: each `/health` / `/ready` request *and* its "request completed" line.

## Tools

| Command | What it does |
|---|---|
| `smb-logs <project> <env> [YYYY-MM-DD]` | Download one day's log (default: today, UTC) to `~/<project>-logs/<env>/` |
| `smb-logs <project> <env> --ls` | List the folder on the share: names, sizes, last-change times (no download) |
| `smb-logs <project> --envs` | List the environments in the project config |
| `logview <project> <env>` | Download today's log, open it in lnav, refresh every 60 s |
| `logview <project> <env> --every 30` | Refresh every 30 s (minimum 10) |
| `logview <project> <env> 2026-11-25` | A past day (no refresh — the file is finished) |
| `logview <project> <env> --all` | The raw file, health checks included |
| `logview-filter RAW VIEW` | (used by `logview`) append RAW's new lines minus health checks to VIEW |

## Install

Needs Linux with `bash`, `python3`, `smbclient` and `lnav` (Ubuntu/Debian: `sudo apt install smbclient lnav python3`).

```bash
git clone git@github.com:<you>/smb-logview.git
cd smb-logview
./install.sh            # copies to ~/.local/bin and ~/.config/lnav/formats/installed
```

Re-run `./install.sh` after `git pull` to update.

## Configure a project

One file per project: `~/.config/smb-logs/<project>.conf`, one line per environment:

```
# <env>  <//server/share>       <folder on the share>     <file name pattern>
stg      //10.0.0.10/logs-uat   myteam/uat-myapp          app.{date}.1.log
prod     //10.0.0.20/logs-prod  myteam/prod-myapp         app.{date}.1.log
```

`{date}` becomes `YYYY-MM-DD`. Start from `config/example.conf`. Access is anonymous (`smbclient -N`);
usually the share is reachable only over a VPN. **Real configs never go into this repository**
(`.gitignore` excludes `*.conf`).

Then: `smb-logs myapp --envs`, `smb-logs myapp prod --ls`, `logview myapp prod`.

## Settings

| Variable | Default | Meaning |
|---|---|---|
| `SMB_LOGS_TIMEOUT` | `60` | Hard time limit (seconds) for one download. Raise it for big files on a slow share. |
| `LOGVIEW_NOISE` | `/health,/ready` | Comma-separated URL paths whose requests are hidden |

## In lnav

| Key | Action |
|---|---|
| `q` | quit (also stops the refresh) |
| `e` / `E` | next / previous error |
| `w` / `W` | next / previous warning |
| `/text` | search |
| `:filter-in text` / `:filter-out text` | show only / hide lines with text; `TAB` toggles filters |
| `;` | SQL, e.g. `;SELECT log_level, count(*) FROM pino_json GROUP BY 1` |
| `?` | help |

Times are shown in your **local time zone**; the raw JSON has UTC.

## JSON log format

`lnav/pino_json.json` teaches lnav the [pino](https://getpino.io) layout most Node.js services use:
`time`, `level` (string), `msg`, `reqId`, `req.method`, `req.url`, `res.statusCode`. Lines show as
`time LEVEL METHOD URL STATUS message`; other fields appear indented below the line. It applies to files
named `app.<date>.<n>.log` — change `file-pattern` in the format file for other names. Other log
formats (plain text, syslog, nginx …) are recognised by lnav itself.

## How the live view works

`logview` downloads the full file once (`smb-logs`), then a background loop runs every N seconds:
`smbclient reget` appends only the new bytes to the local copy, and `logview-filter` appends the new
complete lines (minus health checks) to a view copy in `~/<project>-logs/<env>/view/`, which lnav
follows. At midnight UTC it switches to the next day's file. A failed refresh (slow share, VPN off) is
skipped and noted in `~/<project>-logs/<env>/.logview-refresh.log`; the next one tries again.

## Notes

- Local copies are `chmod 600` (folders `700`) — logs can hold personal data; delete them when done.
- Do not read logs through a GVFS/FUSE mount (`/run/user/<uid>/gvfs/…`) in scripts: a slow SMB read
  there cannot be interrupted.

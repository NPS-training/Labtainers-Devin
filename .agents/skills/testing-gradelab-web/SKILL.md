---
name: testing-gradelab-web
description: How to run and test the Labtainers instructor grading web server (gradelab -w / flask/server.py) end to end with Docker
---

# Testing the instructor grading web server

## Full end-to-end flow (preferred, works on a box with Docker)
1. Pull the grader image once: `docker pull labtainers/labtainer.grader` (~1 GB, a few minutes).
2. Stage sample student artifacts from the repo's testsets, e.g. for telnetlab:
   `mkdir -p ~/labtainer_xfer/telnetlab && cp $LABTAINER_DIR/testsets/labs/telnetlab/GOLD/*.zip ~/labtainer_xfer/telnetlab/`
   (HOST_HOME_XFER is `labtainer_xfer/` per config/labtainer.config; many labs have GOLD zips under testsets/labs/<lab>/GOLD/.)
3. Run from the instructor dir with LABTAINER_DIR set to repo root:
   `export LABTAINER_DIR=/path/to/repo && cd $LABTAINER_DIR/scripts/labtainer-instructor && ./bin/gradelab -w <labname>`
   It prints a grades table then "Point your browser to http://localhost:8008". The container is `<labname>-igrader` and keeps running with the Flask server (scripts/labtainer-instructor/flask/server.py) inside.
4. Main UI page is http://localhost:8008/grades (the `/` root serves docs/index). Student links go to `/grades/<student_id>`.
5. To rerun cleanly: `docker rm -f <labname>-igrader` (or use `gradelab -r` to redo).

## Useful checks
- Port binding: `docker port <labname>-igrader` — after the loopback hardening PR it should show `8008/tcp -> 127.0.0.1:8008`; before it showed 0.0.0.0.
- Induce an unhandled exception (to test debug mode off): browse `/grades/bogus.student.zip` — student_select does os.listdir on a nonexistent dir. With debug=False you get a plain "Internal Server Error" page; with debug=True the Werkzeug interactive debugger appears.
- Non-loopback reachability: `curl -m 5 http://<host primary IP>:8008/grades` should fail with connection refused when bound to 127.0.0.1.

## Fallback without Docker
Run the server directly: `/opt/labtainer/venv/bin/python3 scripts/labtainer-instructor/flask/server.py <labname>` with HOME pointing at a dir containing `<labname>.grades.json`, `<labname>.grades.txt`, and per-student dirs (mirrors /home/instructor inside the grader). Requires flask<2.3, werkzeug<2.3, flask_table (already in blueprint maintenance).

## Environment
- LABTAINER_DIR must be exported to the repo root; scripts use /opt/labtainer/venv/bin/python3.
- Docker must be running; grader image is on Docker Hub (labtainers/labtainer.grader).

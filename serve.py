#!/usr/bin/env python
from watchdog.events import FileSystemEventHandler
from watchdog.observers import Observer
import asyncio
import itertools
import livereload
import livereload.watcher
import logging
import tornado.ioloop
import watchdog.events

global event_loop
event_loop = asyncio.new_event_loop()
asyncio.set_event_loop(event_loop)

logger = logging.getLogger('livereload')

def common_prefix(strings):
    def all_same(x):
        return all(x[0] == y for y in x)

    char_tuples = itertools.izip(*strings)
    prefix_tuples = itertools.takewhile(all_same, char_tuples)
    return ''.join(x[0] for x in prefix_tuples)

async def run_command(cmd):
    logger.info("$ " + cmd)
    proc = await asyncio.create_subprocess_shell(
        cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT)

    stdout, stderr = await proc.communicate()

    return proc.returncode, stdout.decode()

async def run_middleman(filepath):
    if filepath.startswith('source/'):
        filepath = filepath.removeprefix('source/')
        if filepath.endswith('*'):
            cmd = f"bundle exec middleman build --environment=development --glob='{filepath}' --no-clean"
        else:
            convert = {
                '.adoc': '.html',
                '.bib': '.html',
                '.css.sass': '.css',
                '.js': '.js',
            }
            for ext in convert.keys():
                if filepath.endswith(ext):
                    filepath = filepath.removesuffix(ext) + convert[ext]
                    cmd = f"bundle exec middleman build --environment=development --glob='{filepath}' --no-clean"
                    break
            else:
                cmd = "bundle exec middleman build --environment=development"
    else:
        cmd = "bundle exec middleman build --environment=development"
    rc, stdout = await run_command(cmd)
    if rc != 0:
        logger.error(stdout)

async def middleman_changed(filepaths, reload_callback):
    if len(filepaths) > 1:
        filepath = '*' #common_prefix(filepaths) + '*'
    else:
        filepath = filepaths[0]
    
    await run_middleman(filepath)
    reload_callback()

class WatchdogWatcher(livereload.watcher.Watcher):
    def __init__(self):
        super().__init__()

        self.observer = Observer()
        self.reload_callback = None

    def watch(self, path, func=None, delay=None, ignore=None):
        super().watch(path)

    def schedule(self, path, handler, recursive=True):
        return self.observer.schedule(handler, path, recursive=recursive)

    def start(self, reload_callback):
        if not self.reload_callback:
            self.reload_callback = reload_callback
            self.observer.start()
            reload_callback()
        return True

class MiddlemanHandler(FileSystemEventHandler):
    def __init__(self, watcher):
        self._changes = []
        self._task = None
        self._watcher = watcher
        self._once = False

    def _initialize(self):
        if not self._once:
            asyncio.set_event_loop(event_loop)
            self._once = True
        
    def on_modified(self, event):
        self._initialize()
        if isinstance(event, watchdog.events.DirModifiedEvent):
            return
        event_loop.call_soon_threadsafe(lambda: self.add_and_run(event.src_path))

    def on_created(self, event):
        self._initialize()
        if isinstance(event, watchdog.events.DirModifiedEvent):
            return
        event_loop.call_soon_threadsafe(lambda: self.add_and_run(event.src_path))

    def add_and_run(self, path):
        ignore = ['.bak', '.bkp']
        if any(path.endswith(ext) for ext in ignore):
            logger.info(f"Ignoring: {path}")
            return

        logger.info(f"File changed: {path}")
        if path not in self._changes:
            self._changes.append(path)
        self.maybe_run()

    def maybe_run(self):
        if self._changes and self._task is None or self._task.done():
            changes_copy = self._changes.copy()
            self._changes = []
            self._task = asyncio.create_task(middleman_changed(changes_copy, self._watcher.reload_callback))
            event_loop.call_soon(lambda: self.maybe_run())

watcher = WatchdogWatcher()
middleman_handler = MiddlemanHandler(watcher)
watcher.schedule('source', middleman_handler, recursive=True)
watcher.schedule('config.rb', middleman_handler, recursive=False)
watcher.schedule('asciidoc_extensions', middleman_handler, recursive=True)
watcher.schedule('asciidoc_templates', middleman_handler, recursive=True)

server = livereload.Server(watcher=watcher)
#middleman_build = livereload.shell('bundle exec middleman build --environment=development')
#middleman_build()
server.serve(root='build/', port=4567)

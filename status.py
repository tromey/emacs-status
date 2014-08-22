# status.py - status icon helper for status.el
# Copyright (C) 2014 Tom Tromey <tom@tromey.com>

from gi.repository import Gtk, Gdk, GObject, Notify

import threading
import Queue
import sys
import os

(read_pipe, write_pipe) = os.pipe()
_event_queue = Queue.Queue()

class StdinThread(threading.Thread):
    # Send a message to the main thread.
    def send_to_gtk(self, func):
        _event_queue.put(func)
        os.write(write_pipe, 'x')

    # The function implementing this thread.
    # It reads each line and acts on it.
    def run(self):
        while True:
            data = sys.stdin.readline()
            if not data:
                break
            self.send_to_gtk(lambda: dispatch(data.strip()))
        os._exit(0)

# Read from the queue and call a function.
def handle_queue(source, condition):
    global _event_queue
    os.read(source, 1)
    func = _event_queue.get()
    func()
    return True

class StatusIcon:
    def __init__(self):
        self.click = 'click'
        self.icon = Gtk.StatusIcon()
        self.icon.set_visible(False)
        self.icon.connect('activate', self._activate)

    def _activate(self, widget, data = None):
        print self.click

    def do_icon(self, arg):
        if arg in ['warning', 'info', 'question', 'error']:
            self.icon.set_from_icon_name(arg)
        else:
            self.icon.set_from_file(arg)

    def do_click(self, arg):
        self.click = arg

    def do_visible(self, arg):
        self.icon.set_visible(arg == 'true')

    def do_message(self, arg):
        m = Notify.Notification.new(arg, None, None)
        m.show()

    def do_tooltip(self, arg):
        self.icon.set_tooltip_text(arg)
        self.icon.set_has_tooltip(True)

    def do_blink(self, arg):
        self.icon.set_blinking(arg == 'true')

    def show(self):
        self.icon = gtk.StatusIcon()
        self.icon.set_icon(self.icon_name)
        # fixme
        
icon = StatusIcon()

def dispatch(arg):
    n = arg.find(':')
    method = 'do_' + arg[:n]
    arg = arg[n + 1:].strip()
    getattr(icon, method)(arg)

GObject.threads_init()
Gdk.threads_init()
GObject.io_add_watch(read_pipe, GObject.IO_IN, handle_queue)
Notify.init('status')
StdinThread().start()
Gtk.main()

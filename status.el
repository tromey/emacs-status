;;; status.el --- notification area support for Emacs.

;; Copyright (C) 2007, 2012, 2014 Tom Tromey <tom@tromey.com>

;; Author: Tom Tromey <tom@tromey.com>
;; Version: 0.2
;; Keywords: frames multimedia

;; This file is not (yet) part of GNU Emacs.
;; However, it is distributed under the same license.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;; Commentary:

;; To use this package you will need a specially modified version of
;; zenity, a Gnome program.  The patch is available in Gnome bugzilla:
;;
;;   http://bugzilla.gnome.org/show_bug.cgi?id=310001
;;
;; I realize this is a burden.  I would like to have direct support
;; for the notification area in Emacs itself.  That way, not only
;; could it be made to work cross-platform, but also we have it use
;; real menus, rather than the more limited ones provided by this
;; module.

;; Once you have installed a hacked zenity, you will need to put this
;; file into your load-path, and then (load "status").
;; (Or you can deal with the autoload...)
;; You will also need to set status-zenity-path to point to your copy
;; of zenity:
;;    (setq status-zenity-path "/full/path/to/zenity")

;; There are no user-visible features of this module, only features
;; for Emacs Lisp programs.  You may like to use erc-status.el, which
;; provides some nice notification area support for ERC.

;; Change log:

;; 2007-03-24   updated documentation, added autoload, added variable
;;              for path
;; 2007-03-01   generate new buffer name for each status-new
;; 2007-01-29   reorder code in status-process-filter

;; ToDo:

;; * We should not use zenity.  Instead the code should be built
;;   into Emacs, so that we can use ordinary menus instead of the
;;   more limited ones zenity provides.

(require 'cl)

(defvar status-zenity-path "/home/tromey/gnu/zenity/install/bin/zenity"
  "Path to specially modified version of zenity.")

;; Callback function for a left-click on the status icon.  Internal.
(defvar status-click-callback)
(make-variable-buffer-local 'status-click-callback)

;; Callback alist for status icon.  Internal.
(defvar status-menu-callbacks)
(make-variable-buffer-local 'status-menu-callbacks)

;; Data used by the process filter.  Internal.
(defvar status-input-string)
(make-variable-buffer-local 'status-input-string)

(defun status-set-menu (status-icon menu)
  "Set the context menu on the status icon.
STATUS-ICON is the icon.  MENU is a list of cons cells.  The car of a
cell is the text for the menu label.  The cdr of a cell is a callback
function.  This function is called with no arguments when the menu
item is selected by the user.  If MENU is nil, any existing menu
is removed."
  (process-send-string status-icon "menu:\n")
  (let ((callbacks nil)
	(count 0))
    (while menu
      (process-send-string status-icon
			   (concat "menuitem: "
				   (shell-quote-argument (car (car menu)))
				   (int-to-string count)
				   "\n"))
      (setq callbacks (cons (cons (int-to-string count) (cdr (car menu)))
			    callbacks))
      (setq count (+ 1 count))
      (setq menu (cdr menu)))
    (process-send-string status-icon "endmenu:\n")
    (save-excursion
      (set-buffer (process-buffer status-icon))
      (setq status-menu-callbacks callbacks))))

;;;###autoload
(defun status-new ()
  "Create a new status icon and return it."
  (let ((result (start-process "status-icon"
			       (generate-new-buffer-name " *status-icon*")
			       status-zenity-path
			       "--notification"
			       "--listen")))
    (set-process-filter result 'status-process-filter)
    ;; Default to the GNU.
    (process-send-string result "icon: /usr/share/pixmaps/emacs.png\n")
    (process-send-string result "click: click\n")
    (process-kill-without-query result nil)
    result))

(defun status-set-click-callback (status-icon function)
  "Set the click callback function.
STATUS-ICON is the status icon.  FUNCTION is the callback function.
It will be called with no arguments when the user clicks on the
status icon."
  (save-excursion
    (set-buffer (process-buffer status-icon))
    (setq status-click-callback function)))

;; Set the icon, either to a file name or to a stock icon name.
(defun status-set-icon (status-icon file-or-name)
  "Set the image for the status icon.
STATUS-ICON is the status icon object.  FILE-OR-NAME is either a file
name, or it is one of the stock icon names: \"warning\", \"info\",
\"question\", or \"error\"."
  (process-send-string status-icon (concat "icon: " file-or-name "\n")))

(defun status-set-visible (status-icon arg)
  "Make the status icon visible or invisible.
If ARG is nil, make icon invisible.  Otherwise, make it visible"
  (process-send-string status-icon (concat "visible: "
					   (if arg "true" "false"))))

(defun status-post-message (status-icon text)
  "Post a message by the status icon.
STATUS-ICON is the status icon object.  TEXT is the text to post.
It will appear as a popup near the icon.  TEXT should not contain
any newlines."
  (process-send-string status-icon (concat "message:" text "\n")))

(defun status-set-tooltip (status-icon text)
  "Set the tooltip for the status icon."
  (process-send-string status-icon (concat "tooltip: " text "\n")))

(defun status-delete (status-icon)
  "Destroy the status icon."
  (delete-process status-icon))

(defun status-set-blink (status-icon arg)
  "Enable or disable blinking of the status icon.
If ARG is nil, blinking will be disabled.  Otherwise it will be enabled."
  (process-send-string status-icon (concat "blink: "
					   (if arg "true" "false")
					   "\n")))

(defun status-process-filter (status-icon string)
  (save-excursion
    (set-buffer (process-buffer status-icon))
    (setq status-input-string (concat status-input-string string))
    (let ((index nil))
      ;; FIXME?  uses search from cl.
      (while (setq index (search "\n" status-input-string))
	(let ((cb-name (substring status-input-string 0 index)))
	  (setq status-input-string
		(substring status-input-string (+ 1 index)))
	  ;; Look for the callback.
	  (if (equal cb-name "click")
	      (and status-click-callback
		   (funcall status-click-callback))
	    (let ((elt (assoc status-click-callback status-menu-callbacks)))
	      (and elt (funcall (cdr elt))))))))))

(provide 'status)

;;; status.el ends here

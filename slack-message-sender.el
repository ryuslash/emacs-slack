;;; slack-message-sender.el --- slack message concern message sending  -*- lexical-binding: t; -*-

;; Copyright (C) 2015  yuya.minami

;; Author: yuya.minami <yuya.minami@yuyaminami-no-MacBook-Pro.local>
;; Keywords:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;

;;; Code:

(require 'eieio)
(require 'json)
(require 'slack-websocket)
(require 'slack-im)
(require 'slack-group)
(require 'slack-message)

(defvar slack-message-id 0)
(defvar slack-message-minibuffer-local-map nil)
(defvar slack-message-write-buffer-name "*Slack - Message Writing*")
(defvar slack-sent-message)
(defvar slack-buffer-function)

(defun slack-message-send ()
  (interactive)
  (slack-message--send (slack-message-read-from-minibuffer)))

(defun slack-message--send (message)
  (let* ((m (list :id slack-message-id
                  :channel (slack-message-get-room-id)
                  :type "message"
                  :user (slack-my-user-id)
                  :text message))
         (json (json-encode m))
         (obj (slack-message-create m)))
    (cl-incf slack-message-id)
    (slack-ws-send json)
    (push obj slack-sent-message)))

(defun slack-message-get-room-id ()
  (if (boundp 'slack-current-room)
      (oref slack-current-room id)
    (oref (slack-message-read-room) id)))

(defun slack-message-read-room ()
  (let* ((list (slack-message-room-list))
         (choices (mapcar #'car list))
         (room-name (slack-message-read-room-list "Select Room: " choices))
         (room (cdr (cl-assoc room-name list :test #'string=))))
    room))

(defun slack-message-read-room-list (prompt choices)
  (let ((completion-ignore-case t))
    (completing-read (format "%s" prompt)
                     choices nil t nil nil choices)))

(defun slack-message-room-list ()
  (append (slack-group-names) (slack-im-names)))

(defun slack-message-read-from-minibuffer ()
  (let ((prompt "Message: "))
    (slack-message-setup-minibuffer-keymap)
    (read-from-minibuffer
     prompt
     nil
     slack-message-minibuffer-local-map)))

(defun slack-message-setup-minibuffer-keymap ()
  (unless slack-message-minibuffer-local-map
    (setq slack-message-minibuffer-local-map
          (let ((map (make-sparse-keymap)))
            (define-key map (kbd "RET") 'newline)
            (set-keymap-parent map minibuffer-local-map)
            map))))

(defun slack-message-write-current-buffer ()
  (interactive)
  (with-current-buffer (current-buffer)
    (setq buffer-read-only nil)
    (message "Write message and call `slack-message-send-from-region'")))

(defun slack-message-write-another-buffer ()
  (interactive)
  (let ((target-room (if (boundp 'slack-current-room) slack-current-room
                       (slack-message-read-room)))
        (buf (get-buffer-create slack-message-write-buffer-name)))
    (with-current-buffer buf
      (setq buffer-read-only nil)
      (erase-buffer)
      (slack-mode)
      (insert (format "use `slack-message-send-from-region' to send message to %s\n"
                      (slack-room-name target-room)))
      (insert "use `slack-message-embed-mention' to write @someone\n")
      (insert "---------------------------------------------------\n")
      (slack-buffer-set-current-room target-room))
    (funcall slack-buffer-function buf)))

(defun slack-message-send-from-region (beg end)
  (interactive "r")
  (let ((message (delete-and-extract-region beg end)))
    (if (< 0 (length message))
      (slack-message--send message))))

(defun slack-message-embed-mention ()
  (interactive)
  (let* ((name-with-id (slack-user-names))
        (list (mapcar #'car name-with-id)))
    (slack-room-select-from-list
     (list "Select User: ")
     (let* ((user-id (cdr (cl-assoc selected
                                    name-with-id
                                   :test #'string=)))
            (user-name (slack-user-name user-id)))
       (insert (concat "<@" user-id "|" user-name ">"))))))


(provide 'slack-message-sender)
;;; slack-message-sender.el ends here

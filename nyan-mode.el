;;; nyan-mode.el --- Nyan Cat shows position in current buffer in mode-line  -*- lexical-binding: t; -*-

;; Nyanyanyanyanyanyanya!

;; Author: Jacek "TeMPOraL" Zlydach <temporal.pl@gmail.com>
;; URL: https://github.com/TeMPOraL/nyan-mode/
;; Version: 1.1.4
;; Keywords: convenience, games, mouse, multimedia
;; Nyanwords: nyan, cat, lulz, scrolling, pop tart cat, build something amazing
;; Package-Requires: ((emacs "24.1"))

;; This file is not part of GNU Emacs.

;; ...yet. ;).

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; Commentary:

;; NEW! You can now click on the rainbow (or the empty space)
;; to scroll your buffer!

;; NEW! You can now customize the minimum window width
;; below which the nyan-mode will be disabled, so that more important
;; information can be shown in the modeline.

;; To activate, just load and put `(nyan-mode 1)' in your init file.

;; Contributions and feature requests welcome!

;; Inspired by (and in few places copied from) sml-modeline.el written by Lennart Borgman.
;; See: http://bazaar.launchpad.net/~nxhtml/nxhtml/main/annotate/head%3A/util/sml-modeline.el

;;; History:

;; 2016-04-26 - introduced click-to-scroll feature.

;; Started as a totally random idea back in August 2011.

;; The homepage at http://nyan-mode.buildsomethingamazing.com died somewhen in 2014/2015 because reasons.
;; I might get the domain back one day.

;;; Code:

(defconst nyan-directory (file-name-directory (or load-file-name buffer-file-name)))

(defconst nyan-cat-size 3)

(defconst nyan-cat-face-image (concat nyan-directory "img/nyan.xpm"))
(defconst nyan-rainbow-image (concat nyan-directory "img/rainbow.xpm"))
(defconst nyan-outerspace-image (concat nyan-directory "img/outerspace.xpm"))

(defconst nyan-music (concat nyan-directory "mus/nyanlooped.mp3"))

(defconst nyan-modeline-help-string "Nyanyanya!\nmouse-1: Scroll buffer position")

(defvar nyan-old-car-mode-line-position nil)

(defgroup nyan nil
  "Customization group for `nyan-mode'."
  :group 'frames)

(defun nyan-refresh ()
  "Refresh nyan mode.
Intended to be called when customizations were changed, to
reapply them immediately."
  (when (featurep 'nyan-mode)
    (when (and (boundp 'nyan-mode)
               nyan-mode)
      ;; Re-initialize TTY faces if needed
      (when (and (not (display-graphic-p))
                 nyan-rainbow-use-colors)
        (nyan-define-rainbow-faces))
      (nyan-mode -1)
      (nyan-mode 1))))

;;; TTY Mode Enhanced Rainbow Support
;;; ==================================
;;;
;;; When running in a terminal (non-graphical) environment, nyan-mode can display
;;; colorful rainbow trails and cute characters instead of plain ASCII.
;;;
;;; To enable: (setq nyan-rainbow-use-colors t)
;;;
;;; Try these commands to customize the appearance:
;;;   M-x nyan-cycle-cute-style      - Change rainbow style
;;;   M-x nyan-cycle-cat-style       - Change cat appearance
;;;   M-x nyan-cycle-space-style     - Change space background
;;;   M-x nyan-preset-kawaii         - Apply cute preset
;;;   M-x nyan-preset-galaxy         - Apply space theme
;;;   M-x nyan-preset-retro          - Apply retro/vaporwave theme

;;; TTY Mode Customization Variables
;;; ==================================

(defcustom nyan-animation-frame-interval 0.2
  "Number of seconds between animation frames."
  :type 'float
  :set (lambda (sym val)
         (set-default sym val)
         (nyan-refresh))
  :group 'nyan)

(defvar nyan-animation-timer nil)

(defun nyan--is-animating-p ()
  "T if animating, NIL otherwise."
  (timerp nyan-animation-timer))

(defun nyan-start-animation ()
  (interactive)
  (unless (nyan--is-animating-p)
    (setq nyan-animation-timer (run-at-time "1 sec"
                                            nyan-animation-frame-interval
                                            'nyan-swich-anim-frame))))

(defun nyan-stop-animation ()
  (interactive)
  (when (nyan--is-animating-p)
    (cancel-timer nyan-animation-timer)
    (setq nyan-animation-timer nil)))

(defcustom nyan-force-ascii-mode nil
  "Force ASCII/TTY mode even in graphical Emacs.
When non-nil, nyan-mode will use text characters instead of images
even when running in a GUI environment."
  :type '(choice (const :tag "Auto (use GUI when available)" nil)
                 (const :tag "Force ASCII mode" t))
  :set (lambda (sym val)
         (set-default sym val)
         (nyan-refresh))
  :group 'nyan)

(defcustom nyan-minimum-window-width 64
  "Minimum width of the window, below which nyan-mode will not be displayed.
This is important because nyan-mode will push out all
informations from small windows."
  :type 'integer
  :set (lambda (sym val)
         (set-default sym val)
         (nyan-refresh))
  :group 'nyan)

;;; FIXME bug, doesn't work for antoszka.
(defcustom nyan-wavy-trail nil
  "If enabled, Nyan Cat's rainbow trail will be wavy."
  :type '(choice (const :tag "Enabled" t)
                 (const :tag "Disabled" nil))
  :set (lambda (sym val)
         (set-default sym val)
         (nyan-refresh))
  :group 'nyan)

(defcustom nyan-bar-length 32
  "Length of Nyan Cat bar in units.
Each unit is equal to an 8px image.
Minimum of 3 units are required for Nyan Cat."
  :type 'integer
  :set (lambda (sym val)
         (set-default sym val)
         (nyan-refresh))
  :group 'nyan)

(defcustom nyan-animate-nyancat nil
  "Enable animation for Nyan Cat.
This can be t or nil."
  :type '(choice (const :tag "Enabled" t)
                 (const :tag "Disabled" nil))
  ;; FIXME: Starting an animation timer on defcustom isn't a good idea; this needs to, at best, maybe start/stop a timer iff the mode is on,
  ;; otherwise just set a flag. -- Jacek Złydach, 2020-05-26
  :set (lambda (sym val)
         (set-default sym val)
         (if val
             (nyan-start-animation)
           (nyan-stop-animation))
         (nyan-refresh))
  :group 'nyan)

(defcustom nyan-cat-face-number 1
  "Select cat face number for console."
  :type 'integer
  :group 'nyan)

(defcustom nyan-rainbow-use-colors nil
  "Enable rainbow colors in TTY mode.
When nil, falls back to default behavior (plain characters)."
  :type 'boolean
  :set (lambda (sym val)
         (set-default sym val)
         (nyan-refresh))
  :group 'nyan)

(defcustom nyan-rainbow-style 'solid-background
  "Visual style for the rainbow in TTY mode.
'foreground-only - Colored characters on default background
'background-only - Default characters on colored background
'solid-background - Solid blocks with colored backgrounds
'cute-stars - Mix of blocks and nerd font stars with colors
'galaxy-trail - Alternating blocks and sparkles for a space theme"
  :type '(choice (const :tag "Foreground colors only" foreground-only)
                 (const :tag "Background colors only" background-only)
                 (const :tag "Solid colored blocks" solid-background)
                 (const :tag "Cute stars and blocks" cute-stars)
                 (const :tag "Galaxy trail" galaxy-trail))
  :set (lambda (sym val)
         (set-default sym val)
         (nyan-refresh))
  :group 'nyan)

(defcustom nyan-rainbow-colors
  '("red" "orange" "yellow" "green" "blue" "indigo" "violet")
  "List of colors to use for the rainbow in TTY mode.
Colors cycle through this list. Can be color names or hex values."
  :type '(repeat string)
  :set (lambda (sym val)
         (set-default sym val)
         (nyan-refresh))
  :group 'nyan)

(defcustom nyan-inactive-rainbow-colors
  '("lavenderblush4" "mistyrose4" "navajowhite4" "honeydew4" "azure4" "royalblue4" "slateblue4")
  "List of colors to use for the rainbow in inactive windows in TTY mode.
Colors cycle through this list. Can be color names or hex values."
  :type '(repeat string)
  :set (lambda (sym val)
         (set-default sym val)
         (nyan-refresh))
  :group 'nyan)

(defcustom nyan-star-colors
  '("white" "silver" "light grey")
  "List of colors to use for the stars in TTY mode.
Colors cycle through this list. Can be color names or hex values."
  :type '(repeat string)
  :set (lambda (sym val)
         (set-default sym val)
         (nyan-refresh))
  :group 'nyan)

(defcustom nyan-inactive-star-colors
  '("white" "silver" "light grey")
  "List of colors to use for the stars in TTY mode.
Colors cycle through this list. Can be color names or hex values."
  :type '(repeat string)
  :set (lambda (sym val)
         (set-default sym val)
         (nyan-refresh))
  :group 'nyan)

(defcustom nyan-space-color "black"
  "Color to use for the background of space in TTY mode.
Can be a color name like 'black' or a hex value like '#000000'."
  :type 'string
  :set (lambda (sym val)
         (set-default sym val)
         (nyan-refresh))
  :group 'nyan)

(defcustom nyan-inactive-space-color "black"
  "Color to use for the background of space in inactive windows in TTY mode.
Can be a color name like 'black' or a hex value like '#000000'."
  :type 'string
  :set (lambda (sym val)
         (set-default sym val)
         (nyan-refresh))
  :group 'nyan)

(defcustom nyan-cat-background-color "hot pink"
  "Background color for the nyan cat when using kaomoji-with-bg style.
Can be a color name like 'hot pink' or a hex value like '#ff69b4'."
  :type 'string
  :set (lambda (sym val)
         (set-default sym val)
         (nyan-refresh))
  :group 'nyan)

(defcustom nyan-cat-foreground-color "white"
  "Foreground (text) color for the nyan cat when using kaomoji-with-bg style.
Can be a color name like 'white' or a hex value like '#ffffff'."
  :type 'string
  :set (lambda (sym val)
         (set-default sym val)
         (nyan-refresh))
  :group 'nyan)

(defcustom nyan-cat-inactive-background-color "black"
  "Background color for the nyan cat in inactive windows when using kaomoji-with-bg style.
Can be a color name like 'black' or a hex value like '#000000'."
  :type 'string
  :set (lambda (sym val)
         (set-default sym val)
         (nyan-refresh))
  :group 'nyan)

(defcustom nyan-cat-inactive-foreground-color "white"
  "Foreground (text) color for the nyan cat in inactive windows when using kaomoji-with-bg style.
Can be a color name like 'white' or a hex value like '#ffffff'."
  :type 'string
  :set (lambda (sym val)
         (set-default sym val)
         (nyan-refresh))
  :group 'nyan)

(defcustom nyan-cat-cute-style 'kaomoji-with-bg
  "Style for the nyan cat in TTY mode.
'kaomoji-only - Just the kaomoji face
'kaomoji-with-bg - Kaomoji with a cute background color
'nerd-cat - Use nerd font cat icon with colors
'emoji-cat - Use emoji cat (if terminal supports it)"
  :type '(choice (const :tag "Kaomoji only" kaomoji-only)
                 (const :tag "Kaomoji with background" kaomoji-with-bg)
                 (const :tag "Nerd font cat" nerd-cat)
                 (const :tag "Emoji cat" emoji-cat))
  :set (lambda (sym val)
         (set-default sym val)
         (nyan-refresh))
  :group 'nyan)

(defcustom nyan-cute-outerspace-style 'starfield
  "Style for the outer space area in TTY mode.
'plain - Simple dashes
'dots - Dotted space
'starfield - Mix of stars and space dots
'void - Dark background with occasional sparkles"
  :type '(choice (const :tag "Plain dashes" plain)
                 (const :tag "Dots" dots)
                 (const :tag "Starfield" starfield)
                 (const :tag "Dark void" void))
  :set (lambda (sym val)
         (set-default sym val)
         (nyan-refresh))
  :group 'nyan)

;;; Load images of Nyan Cat an it's rainbow.
(defvar nyan-cat-image (if (image-type-available-p 'xpm)
                           (create-image nyan-cat-face-image 'xpm nil :ascent 'center)))

(defvar nyan-animation-frames (if (image-type-available-p 'xpm)
                                  (mapcar (lambda (id)
                                            (create-image (concat nyan-directory (format "img/nyan-frame-%d.xpm" id))
                                                          'xpm nil :ascent 95))
                                          '(1 2 3 4 5 6))))
(defvar nyan-current-frame 0)

;;; TTY Mode Character Definitions
;;; ===============================

(defconst nyan-cute-chars
  '((block . "█")
    (half-block . "▌")
    (light-block . "░")
    (medium-block . "▒")
    (dark-block . "▓")
    (star . "✦")
    (sparkle . "")
    (tiny-sparkles . "")
    (twinkle . "✧")
    (diamond . "♦")
    (heart . "♥")
    (dot . "·")
    (bullet . "•")
    (circle . "○")
    (nerd-cat . "")
    (nerd-star . "")
    (nerd-sparkle . "󰫢")))

(defun nyan-get-char (symbol)
  "Get character for SYMBOL, with fallback for terminals without fancy fonts."
  (let ((char (cdr (assq symbol nyan-cute-chars))))
    (or char "?")))

;;; TTY Mode Face Management
;;; =========================

(defun nyan-define-rainbow-face (index colors-list prefix)
  "Define a single rainbow face for INDEX using COLORS-LIST with PREFIX."
  (let* ((face-name (intern (format "%s-%d" prefix (1+ index))))
         (color (nth index colors-list))
         (face-spec (pcase nyan-rainbow-style
                      ('foreground-only `((t (:foreground ,color :weight bold))))
                      ('background-only `((t (:background ,color))))
                      ('solid-background `((t (:background ,color :foreground ,color))))
                      ('cute-stars `((t (:foreground ,color :weight bold))))
                      ('galaxy-trail `((t (:background ,color :foreground ,(nth 0 nyan-star-colors) :weight bold)))))))
    (custom-declare-face face-name face-spec
                         (format "Nyan %s color %d"
                                (if (string-match "inactive" prefix) "inactive rainbow" "rainbow")
                                (1+ index))
                         :group 'nyan)))

(defun nyan-define-cat-faces ()
  "Define cat-related faces."
  (let ((cat-face-spec (pcase nyan-cat-cute-style
                         ('kaomoji-only `((t (:foreground ,nyan-cat-foreground-color :weight bold))))
                         ('kaomoji-with-bg `((t (:background ,nyan-cat-background-color :foreground ,nyan-cat-foreground-color :weight bold))))
                         ('nerd-cat '((t (:foreground "orange" :weight bold))))
                         ('emoji-cat '((t (:foreground "orange")))))))
    (custom-declare-face 'nyan-cat-cute cat-face-spec "Cute nyan cat face" :group 'nyan))

  (let ((cat-inactive-face-spec (pcase nyan-cat-cute-style
                                  ('kaomoji-only `((t (:foreground ,nyan-cat-inactive-foreground-color :weight bold))))
                                  ('kaomoji-with-bg `((t (:background ,nyan-cat-inactive-background-color :foreground ,nyan-cat-inactive-foreground-color :weight bold))))
                                  ('nerd-cat '((t (:foreground "orange" :weight bold))))
                                  ('emoji-cat '((t (:foreground "orange")))))))
    (custom-declare-face 'nyan-cat-cute-inactive cat-inactive-face-spec "Cute inactive nyan cat face" :group 'nyan))

  ;; Background padding faces
  (custom-declare-face 'nyan-cat-bg-padding `((t (:background ,nyan-space-color :foreground ,nyan-space-color)))
                       "Background padding for cute cat" :group 'nyan)

  (custom-declare-face 'nyan-cat-inactive-bg-padding `((t (:background ,nyan-inactive-space-color :foreground ,nyan-inactive-space-color)))
                       "Background padding for inactive cute cat" :group 'nyan))

(defun nyan-define-space-faces ()
  "Define space-related faces."
  (custom-declare-face 'nyan-space-void `((t (:background ,nyan-space-color :foreground ,(nth 2 nyan-star-colors))))
                       "Dark void of space" :group 'nyan)
  (custom-declare-face 'nyan-space-star `((t (:background ,nyan-space-color :foreground ,(nth 1 nyan-star-colors) :weight bold)))
                       "Twinkling stars" :group 'nyan)
  (custom-declare-face 'nyan-space-sparkle `((t (:background ,nyan-space-color :foreground ,(nth 0 nyan-star-colors) :weight bold)))
                       "Space sparkles" :group 'nyan)

  (custom-declare-face 'nyan-inactive-space-void `((t (:background ,nyan-inactive-space-color :foreground ,(nth 2 nyan-inactive-star-colors))))
                       "Dark inactive void of space" :group 'nyan)
  (custom-declare-face 'nyan-inactive-space-star `((t (:background ,nyan-inactive-space-color :foreground ,(nth 1 nyan-inactive-star-colors) :weight bold)))
                       "Twinkling inactive stars" :group 'nyan)
  (custom-declare-face 'nyan-inactive-space-sparkle `((t (:background ,nyan-inactive-space-color :foreground ,(nth 0 nyan-inactive-star-colors) :weight bold)))
                       "Space inactive sparkles" :group 'nyan))

(defun nyan-define-rainbow-faces ()
  "Define or redefine rainbow faces based on current customization."
  ;; Rainbow segment faces
  (dotimes (i (length nyan-rainbow-colors))
    (nyan-define-rainbow-face i nyan-rainbow-colors "nyan-rainbow"))

  (dotimes (i (length nyan-inactive-rainbow-colors))
    (nyan-define-rainbow-face i nyan-inactive-rainbow-colors "nyan-inactive-rainbow"))

  ;; Cat faces
  (nyan-define-cat-faces)

  ;; Space faces
  (nyan-define-space-faces))

;;; TTY Mode Character Generation
;;; ==============================

(defun nyan-get-rainbow-segment (index)
  "Get a cute rainbow segment character for position INDEX."
  (let* ((color-index (% index (length nyan-rainbow-colors)))
         (face-name (intern (format (if (mode-line-window-selected-p)
                                        "nyan-rainbow-%d"
                                      "nyan-inactive-rainbow-%d") (1+ color-index))))
         (char (pcase nyan-rainbow-style
                 ('foreground-only (nyan-get-char 'block))
                 ('background-only " ")
                 ('solid-background " ")
                 ('cute-stars (if (zerop (% index 3))
                                  (nyan-get-char 'nerd-star)
                                (nyan-get-char 'block)))
                 ('galaxy-trail (pcase (% index 4)
                                  (0 (nyan-get-char 'nerd-sparkle))
                                  (1 (nyan-get-char 'block))
                                  (2 (nyan-get-char 'nerd-star))
                                  (3 (nyan-get-char 'block)))))))
    (propertize char 'face face-name)))

(defun nyan-get-cute-cat ()
  "Get the cute cat representation."
  (pcase nyan-cat-cute-style
    ('kaomoji-only
     (aref (nyan-catface) (nyan-catface-index)))
    ('kaomoji-with-bg
     (concat (propertize " "
                         'face (if (mode-line-window-selected-p)
                                   'nyan-cat-cute
                                 'nyan-cat-cute-inactive))
             (propertize (aref (nyan-catface) (nyan-catface-index))
                         'face (if (mode-line-window-selected-p)
                                   'nyan-cat-cute
                                 'nyan-cat-cute-inactive))
             (propertize " "
                         'face (if (mode-line-window-selected-p)
                                   'nyan-cat-bg-padding
                                 'nyan-cat-inactive-bg-padding))))
    ('nerd-cat
     (propertize (nyan-get-char 'nerd-cat) 'face 'nyan-cat-cute))
    ('emoji-cat
     (propertize "" 'face 'nyan-cat-cute))))

(defun nyan-get-space-segment (index)
  "Get a cute outer space segment for position INDEX."
  (let ((char (pcase nyan-cute-outerspace-style
                ('plain "-")
                ('dots (nyan-get-char 'dot))
                ('starfield (pcase (% index 8)
                              (0 (propertize (nyan-get-char 'tiny-sparkles)
                                             'face (if (mode-line-window-selected-p)
                                                       'nyan-space-star
                                                     'nyan-inactive-space-star)))
                              (3 (propertize (nyan-get-char 'sparkle)
                                             'face (if (mode-line-window-selected-p)
                                                       'nyan-space-sparkle
                                                     'nyan-inactive-space-sparkle)))
                              (6 (propertize (nyan-get-char 'dot)
                                             'face (if (mode-line-window-selected-p)
                                                       'nyan-space-void
                                                     'nyan-inactive-space-void)))
                              (_ (propertize " "
                                             'face (if (mode-line-window-selected-p)
                                                       'nyan-space-void
                                                     'nyan-inactive-space-void)))))
                ('void (pcase (% index 12)
                         (0 (propertize (nyan-get-char 'sparkle)
                                        'face (if (mode-line-window-selected-p)
                                                  'nyan-space-sparkle
                                                'nyan-inactive-space-sparkle)))
                         (7 (propertize (nyan-get-char 'star)
                                        'face (if (mode-line-window-selected-p)
                                                  'nyan-space-star
                                                'nyan-inactive-space-star)))
                         (_ (propertize " "
                                        'face (if (mode-line-window-selected-p)
                                                  'nyan-space-void
                                                'nyan-inactive-space-void))))))))
    (if (stringp char) char char)))

(defconst nyan-cat-face [
                          ["[]*" "[]#"]
                          ["(*^ｰﾟ)" "( ^ｰ^)" "(^ｰ^ )" "(ﾟｰ^*)"]
                          ["(´ω｀三 )" "( ´ω三｀ )" "( ´三ω｀ )" "( 三´ω｀)"
                           "( 三´ω｀)" "( ´三ω｀ )" "( ´ω三｀ )" "(´ω｀三 )"]
                          ["(´д｀;)" "( ´д`;)" "( ;´д`)" "(;´д` )"]
                          ["(」・ω・)」" "(／・ω・)／" "(」・ω・)」" "(／・ω・)／"
                           "(」・ω・)」" "(／・ω・)／" "(」・ω・)」" "＼(・ω・)／"]
                          ["(＞ワ＜三　　　)" "(　＞ワ三＜　　)"
                           "(　　＞三ワ＜　)" "(　　　三＞ワ＜)"
                           "(　　＞三ワ＜　)" "(　＞ワ三＜　　)"]])

(defun nyan-toggle-wavy-trail ()
  "Toggle the trail to look more like the original Nyan Cat animation."
  (interactive)
  (setq nyan-wavy-trail (not nyan-wavy-trail)))

(defun nyan-swich-anim-frame ()
  (setq nyan-current-frame (% (+ 1 nyan-current-frame) 6))
  (force-mode-line-update))

(defun nyan-get-anim-frame ()
  (if (nyan--is-animating-p)
      (nth nyan-current-frame nyan-animation-frames)
    nyan-cat-image))

(defun nyan-wavy-rainbow-ascent (number)
  (if (nyan--is-animating-p)
      (min 100 (+ 90
                  (* 3 (abs (- (/ 6 2)
                               (% (+ number nyan-current-frame)
                                  6))))))
    (if (zerop (% number 2)) 80 'center)))

(defun nyan-number-of-rainbows ()
  (round (/ (* (round (* 100
                         (/ (- (float (point))
                               (float (point-min)))
                            (float (point-max)))))
               (- nyan-bar-length nyan-cat-size))
            100)))

(defun nyan-catface ()
  (aref nyan-cat-face nyan-cat-face-number))

(defun nyan-catface-index ()
  (min (round (/ (* (round (* 100
                              (/ (- (float (point))
                                    (float (point-min)))
                                 (float (point-max)))))
                    (length (nyan-catface)))
                 100))
       (- (length (nyan-catface)) 1)))

(defun nyan-scroll-buffer (percentage buffer)
  "Move point `BUFFER' to `PERCENTAGE' percent in the buffer."
  (interactive)
  (with-current-buffer buffer
    (goto-char (floor (* percentage (point-max))))))

(defun nyan-add-scroll-handler (string percentage buffer)
  "Propertize `STRING' to scroll `BUFFER' to `PERCENTAGE' on click."
  (let ((percentage percentage)
        (buffer buffer))
    (propertize string
                'keymap
                `(keymap (mode-line keymap
                                    (down-mouse-1 . ,(lambda ()
                                                       (interactive)
                                                       (nyan-scroll-buffer percentage buffer))))))))

(defun nyan-create ()
  "Return the Nyan Cat indicator to be inserted into mode line."
  (if (< (window-width) nyan-minimum-window-width)
      ""  ; disabled for too small windows
    (let* ((rainbows (nyan-number-of-rainbows))
           (outerspaces (- nyan-bar-length rainbows nyan-cat-size))
           (rainbow-string "")
	   (xpm-support (and (not nyan-force-ascii-mode)
			     (display-graphic-p)
			     (image-type-available-p 'xpm)))
	   (use-tty-colors (and (or nyan-force-ascii-mode
				    (not (display-graphic-p)))
				nyan-rainbow-use-colors))
           (nyancat-string "")
           (outerspace-string "")
           (buffer (current-buffer)))

      ;; Build rainbow string
      (dotimes (number rainbows)
        (setq rainbow-string
              (concat rainbow-string
                      (nyan-add-scroll-handler
                       (cond
                        (xpm-support
                         (propertize "|"
                                     'display (create-image nyan-rainbow-image 'xpm nil
                                                          :ascent (or (and nyan-wavy-trail
                                                                          (nyan-wavy-rainbow-ascent number))
                                                                     (if (nyan--is-animating-p) 95 'center)))))
                        (use-tty-colors
                         (nyan-get-rainbow-segment number))
                        (t "|"))
                       (/ (float number) nyan-bar-length) buffer))))

      ;; Build cat string
      (setq nyancat-string
            (cond
             (xpm-support
              (propertize (aref (nyan-catface) (nyan-catface-index))
                          'display (nyan-get-anim-frame)))
             (use-tty-colors
              (nyan-get-cute-cat))
             (t
              (aref (nyan-catface) (nyan-catface-index)))))

      ;; Build outer space string
      (dotimes (number outerspaces)
        (setq outerspace-string
              (concat outerspace-string
                      (nyan-add-scroll-handler
                       (cond
                        (xpm-support
                         (propertize "-"
                                     'display (create-image nyan-outerspace-image 'xpm nil
                                                          :ascent (if (nyan--is-animating-p) 95 'center))))
                        (use-tty-colors
                         (nyan-get-space-segment number))
                        (t "-"))
                       (/ (float (+ rainbows nyan-cat-size number)) nyan-bar-length) buffer))))

      ;; Compute final Nyan Cat string
      (propertize (concat rainbow-string
                          nyancat-string
                          outerspace-string)
                  'help-echo (if use-tty-colors
                                "Nyanyanyanya!✨ mouse-1: Scroll buffer position"
                              nyan-modeline-help-string)))))


;;; Music handling.

;; mplayer needs to be installed for that
(defvar nyan-music-process nil)

(defun nyan-start-music ()
  (interactive)
  (unless nyan-music-process
    (setq nyan-music-process (start-process-shell-command "nyan-music"
                                                          "nyan-music"
                                                          (concat "mplayer " nyan-music " -loop 0")))))

(defun nyan-stop-music ()
  (interactive)
  (when nyan-music-process
    (delete-process nyan-music-process)
    (setq nyan-music-process nil)))



;;; Interactive TTY Customization Commands
;;; =======================================

(defun nyan-cycle-cute-style ()
  "Cycle through different cute rainbow styles."
  (interactive)
  (setq nyan-rainbow-style
        (pcase nyan-rainbow-style
          ('foreground-only 'background-only)
          ('background-only 'solid-background)
          ('solid-background 'cute-stars)
          ('cute-stars 'galaxy-trail)
          ('galaxy-trail 'foreground-only)))
  (nyan-define-rainbow-faces)
  (nyan-refresh)
  (message "Nyan style: %s✨" nyan-rainbow-style))

(defun nyan-cycle-cat-style ()
  "Cycle through different cat styles."
  (interactive)
  (setq nyan-cat-cute-style
        (pcase nyan-cat-cute-style
          ('kaomoji-only 'kaomoji-with-bg)
          ('kaomoji-with-bg 'nerd-cat)
          ('nerd-cat 'emoji-cat)
          ('emoji-cat 'kaomoji-only)))
  (nyan-define-rainbow-faces)
  (nyan-refresh)
  (message "Nyan cat style: %s" nyan-cat-cute-style))

(defun nyan-cycle-space-style ()
  "Cycle through different outer space styles."
  (interactive)
  (setq nyan-cute-outerspace-style
        (pcase nyan-cute-outerspace-style
          ('plain 'dots)
          ('dots 'starfield)
          ('starfield 'void)
          ('void 'plain)))
  (nyan-refresh)
  (message "Nyan space style: %s⭐" nyan-cute-outerspace-style))

(defun nyan-toggle-rainbow-colors ()
  "Toggle rainbow colors in TTY mode on/off."
  (interactive)
  (setq nyan-rainbow-use-colors (not nyan-rainbow-use-colors))
  (nyan-refresh)
  (message "Nyan rainbow colors: %s %s"
           (if nyan-rainbow-use-colors "enabled" "disabled")
           (if nyan-rainbow-use-colors "🌈" "")))

(defun nyan-preset-kawaii ()
  "Apply a super cute kawaii preset."
  (interactive)
  (setq nyan-rainbow-style 'cute-stars
        nyan-cat-cute-style 'kaomoji-with-bg
        nyan-cute-outerspace-style 'starfield
        nyan-rainbow-colors '("hot pink" "deep pink" "orange" "gold" "lime green" "cyan" "deep sky blue" "magenta"))
  (nyan-define-rainbow-faces)
  (nyan-refresh)
  (message "Applied kawaii preset! 🌸"))

(defun nyan-preset-galaxy ()
  "Apply a cool galaxy theme preset."
  (interactive)
  (setq nyan-rainbow-style 'galaxy-trail
        nyan-cat-cute-style 'nerd-cat
        nyan-cute-outerspace-style 'void
        nyan-rainbow-colors '("purple" "indigo" "blue" "cyan" "teal" "green" "yellow"))
  (nyan-define-rainbow-faces)
  (nyan-refresh)
  (message "Applied galaxy preset! 🌌"))

(defun nyan-preset-retro ()
  "Apply a retro/vaporwave theme preset."
  (interactive)
  (setq nyan-rainbow-style 'solid-background
        nyan-cat-cute-style 'emoji-cat
        nyan-cute-outerspace-style 'dots
        nyan-rainbow-colors '("magenta" "cyan" "hot pink" "purple" "blue" "teal"))
  (nyan-define-rainbow-faces)
  (nyan-refresh)
  (message "Applied retro preset! 🌆"))

;;;###autoload
(define-minor-mode nyan-mode
  "Use NyanCat to show buffer size and position in mode-line.
You can customize this minor mode, see option `nyan-mode'.

Set `nyan-force-ascii-mode' to t to use text characters even in GUI Emacs.
Set `nyan-rainbow-use-colors' to t for colorful ASCII mode in terminals.

Note: If you turn this mode on then you probably want to turn off
option `scroll-bar-mode'."
  :global t
  :group 'nyan
  ;; FIXME: That doesn't smell right; might still get duplicate nyan cats and other mode-line disruptions.  -- Jacek Złydach, 2020-05-26
  (cond (nyan-mode
         (unless nyan-old-car-mode-line-position
           (setq nyan-old-car-mode-line-position (car mode-line-position)))
         ;; Initialize TTY faces if needed
         (when (and (not (display-graphic-p))
                    nyan-rainbow-use-colors)
           (nyan-define-rainbow-faces))
         (setcar mode-line-position '(:eval (list (nyan-create))))
         ;; NOTE Redundant, but intended to, in the future, prevent the custom variable from starting the animation timer even if nyan mode isn't active. -- Jacek Złydach, 2020-05-26
         (when nyan-animate-nyancat
           (nyan-start-animation)))
        ((not nyan-mode)
         (nyan-stop-animation)          ; In case there was an animation going on.
         (setcar mode-line-position nyan-old-car-mode-line-position)
         (setq nyan-old-car-mode-line-position nil))))


;;; Initialize TTY faces on load if appropriate
(when (and (not (display-graphic-p))
           nyan-rainbow-use-colors
           (boundp 'nyan-mode)
           nyan-mode)
  (nyan-define-rainbow-faces))

(provide 'nyan-mode)

;;; nyan-mode.el ends here

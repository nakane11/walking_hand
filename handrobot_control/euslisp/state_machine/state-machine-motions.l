(setq *stand-pose* #f(89.6063 2.09251 -35.4375 30.5775 11.5425 74.655 -39.96 -1.07999 0.94501 85.8263 -40.4662 -35.2012 -2.19374 79.0763 -40.4662 -52.515 6.71626 74.3513 -34.83))

;; STANDING
(defvar *idle-time* 0.0)
(defvar *idle-time-period* (* 20 pi))
(defun standing-idle-frame ()
  (setq *idle-time* (mod (+ *idle-time* 0.4) *idle-time-period*))
  (let ((current-pose (copy-seq *stand-pose*))
        (pitch-amplitude 10.0) (roll-amplitude 5.0)
        (pitch-joints '(1 4 8 12 16)) (roll-joints '(3 15)))

    ;; 1. 前後揺れ (Pitch)
    (let ((offset-pitch (* pitch-amplitude (sin (* 0.2 *idle-time*)))))
      (dolist (idx pitch-joints)
        (setf (elt current-pose idx) (+ (elt *stand-pose* idx) offset-pitch))))

    ;; 2. 左右揺れ (Roll)
    (let ((inner-wave (sin (* 0.1 *idle-time*)))
          (outer-wave (sin (- (* 0.1 *idle-time*) 0.8)))) ;; 位相を遅らせる
      ;; 内側の指 (振幅は少し控えめに)
      (setf (elt current-pose 7)  (+ (elt *stand-pose* 7)  (* (* 0.5 roll-amplitude) inner-wave))) ;; MIDDLE0
      (setf (elt current-pose 11) (+ (elt *stand-pose* 11) (* (* -0.5 roll-amplitude) inner-wave))) ;; RING0 (逆位相で対称に開く)
      ;; 外側の指 (振幅は大きく、位相は遅れて)
      (setf (elt current-pose 3)  (+ (elt *stand-pose* 3)  (* roll-amplitude outer-wave)))       ;; INDEX0
      (setf (elt current-pose 15) (+ (elt *stand-pose* 15) (* (* -1.0 roll-amplitude) outer-wave)))) ;; LITTLE0 (逆位相)

    (send *ri* :angle-vector current-pose 20)
    )
  )

(defun play-curtsy-motion (&key (base-pose *stand-pose*) (duration 1000))
  (send *ri* :angle-vector-sequence
    (list #f(89.9438 -15.4575 6.04126 34.155 10.9013 53.1563 49.9163 -3.03749 -0.06749 64.6313 29.5988 -31.0162 1.38376 52.11 35.7413 -45.6637 8.94376 61.695 24.5025)
          #f(89.6063 -22.14 4.38751 33.8175 10.5975 52.4813 49.9163 -2.39624 -1.72124 64.9688 30.5775 -32.94 -24.03 100.136 70.2675 -46.305 -1.38374 61.695 24.84)
          #f(98.1113 -8.80874 8.94376 34.4588 42.93 33.9525 81.7425 -4.99499 26.1225 55.4513 73.6425 -36.5175 55.9238 99.1575 60.885 -39.15 14.985 73.035 36.7538))
    (list 500 400 500))
  (send *ri* :wait-interpolation)
  (unix:usleep (* duration 1000))
  (send *ri* :angle-vector-sequence
    (list #f(89.6063 -22.14 4.38751 33.8175 10.5975 52.4813 49.9163 -2.39624 -1.72124 64.9688 30.5775 -32.94 -24.03 100.136 70.2675 -46.305 -1.38374 61.695 24.84)
          #f(88.6275 -23.49 4.72501 33.8175 12.2175 53.4938 51.2325 -3.03749 -2.02499 70.1663 35.775 -31.0162 -38.34 72.8325 75.8025 -44.685 -4.79249 63.315 30.3075)
          #f(89.9438 -15.4575 6.04126 34.155 10.9013 53.1563 49.9163 -3.03749 -0.06749 64.6313 29.5988 -31.0162 1.38376 52.11 35.7413 -45.6637 8.94376 61.695 24.5025))
    (list 500 400 400))
  (send *ri* :wait-interpolation)
  )

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

(define-state-executor execute-state-stand :STANDING
  :transition (
    (ros::ros-info "Transition: -> STAND")
    (send *ri* :servo-on)
    (send *ri* :angle-vector *stand-pose* 2000)
    (send *ri* :wait-interpolation)
    (setq *idle-time* 0.0)
    (ros::ros-info "Transition: STAND complete.")
  )
  :persistent (
    (standing-idle-frame)
  )
)

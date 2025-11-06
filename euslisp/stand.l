(require "package://kxreus/euslisp/kxr-interface.l")
(kxr-init :create-viewer nil)

;; 基準となる「指で立つ」姿勢 (19関節)
(setq *stand-pose* #f(89.6063 2.09251 -35.4375 30.5775 11.5425 74.655 -39.96 -1.07999 0.94501 85.8263 -40.4662 -35.2012 -2.19374 79.0763 -40.4662 -52.515 6.71626 74.3513 -34.83))

;; 揺らす関節のインデックス
(let ((pitch-joints '(1 4 8 12 16))
      (time 0.0)
      (current-pose (copy-seq *stand-pose*))
      (pitch-amplitude 10.0)
      (roll-amplitude 5.0))

  (do-until-key
    (setq time (+ time 0.2))
    (replace current-pose *stand-pose*)

    ;; 1. 前後揺れ (Pitch) - そのまま
    (let ((offset-pitch (* pitch-amplitude (sin (* 0.15 time)))))
      (dolist (idx pitch-joints)
        (setf (elt current-pose idx) (+ (elt *stand-pose* idx) offset-pitch))))

    ;; 2. 左右揺れ (Roll) - 内側から外側へ波及
    ;; 中心 (MIDDLE0, RING0): 位相 0.0 で動く
    ;; 外側 (INDEX0, LITTLE0): 位相を遅らせる (+ 0.8)
    ;; ※ INDEX0は正方向が「外」、LITTLE0は負方向が「外」と仮定して符号を調整
    (let ((inner-wave (sin (* 0.1 time)))
          (outer-wave (sin (- (* 0.1 time) 0.8)))) ;; 位相を遅らせる

      ;; 内側の指 (振幅は少し控えめに)
      (setf (elt current-pose 7)  (+ (elt *stand-pose* 7)  (* (* 0.5 roll-amplitude) inner-wave))) ;; MIDDLE0
      (setf (elt current-pose 11) (+ (elt *stand-pose* 11) (* (* -0.5 roll-amplitude) inner-wave))) ;; RING0 (逆位相で対称に開く)

      ;; 外側の指 (振幅は大きく、位相は遅れて)
      (setf (elt current-pose 3)  (+ (elt *stand-pose* 3)  (* roll-amplitude outer-wave)))       ;; INDEX0
      (setf (elt current-pose 15) (+ (elt *stand-pose* 15) (* (* -1.0 roll-amplitude) outer-wave)))) ;; LITTLE0 (逆位相)

    (send *ri* :angle-vector current-pose 50)
  )
)

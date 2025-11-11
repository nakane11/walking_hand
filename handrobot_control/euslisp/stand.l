(require "package://kxreus/euslisp/kxr-interface.l")
(kxr-init :create-viewer nil)

;; 基準となる「指で立つ」姿勢 (19関節)
(setq *stand-pose* #f(89.6063 2.09251 -35.4375 30.5775 11.5425 74.655 -39.96 -1.07999 0.94501 85.8263 -40.4662 -35.2012 -2.19374 79.0763 -40.4662 -52.515 6.71626 74.3513 -34.83))

(defun stand-to-sit
    (send *ri* :angle-vector-sequence
          (list
           #f(90.2813 -12.7912 65.4413 30.5775 6.75001 62.4375 50.5913 2.09251 -3.71249 63.99 49.7475 -32.2987 -0.57374 35.4038 67.365 -43.3687 11.475 44.7188 70.335)
           #f(81.7763 44.1113 56.0588 28.0125 7.05376 72.6638 49.9163 -4.35374 -4.01624 85.185 55.9238 -38.745 -6.74999 32.6363 65.1375 -46.98 -3.77999 39.825 69.3563)
           #f(66.4538 20.0475 51.5025 28.3163 5.46751 71.01 49.6125 -5.33249 -4.01624 82.89 54.945 -38.4412 -6.74999 33.5475 64.4625 -47.2837 -1.38374 39.825 69.9975)
           #f(68.4113 76.1738 42.7275 27.0338 27.405 91.4625 80.46 5.63626 16.1663 90.0788 73.98 -31.995 12.0825 88.29 77.76 -43.3687 17.55 91.5638 74.25)
           #f(26.055 45.3938 39.4875 33.1763 6.41251 92.1038 81.1013 5.94001 2.59876 88.425 74.9588 -27.4725 4.96126 88.965 79.38 -39.15 -2.42999 87.9863 72.9338))
          (list 500 1000 1000 500 500))
  (send *ri* :wait-interpolation))

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

(ros::load-ros-manifest "kxr_controller")
(load "state-machine-motions.l")

(define-state-executor execute-state-stand :STANDING
  :transition (
    (send *ri* :servo-on)
    (while t
      (setq msg (one-shot-subscribe "/fullbody_controller/servo_on_off_real_interface/state" kxr_controller::ServoOnOff))
      (when (every #'identity (send msg :servo_on_states))
        (return))
      (ros::spin-once)
      (ros::sleep))
    (if (eq *current-state* :SITTING)
        (sit-to-stand)
      (progn
        (send *ri* :angle-vector *stand-pose* 2000)
        (send *ri* :wait-interpolation)))
    (setq *idle-time* 0.0)
    )
  :persistent (
    (standing-idle-frame)
    )
  )
)

(define-state-executor execute-state-pause :PAUSED
  :transition ()
  :persistent ()
)

(define-action-executor execute-action-bow :BOW
  :body (
    (play-curtsy-motion :base-pose *stand-pose* :duration 1000)
  )
)

(define-state-executor execute-state-walk :STAND_WALK
  :transition (
    (unless (eq *current-state* :PAUSED)
      (setq *walk-next-part* :PART1)
      )
    )
  :persistent (
    (cond
      ((eq *walk-next-part* :PART1)
       (send *ri* :angle-vector-sequence *walk-angle-part1*
             (make-list (length *walk-angle-part1*) :initial-element 600))
       (send *ri* :wait-interpolation)
       (setq *walk-next-part* :PART2))

      ((eq *walk-next-part* :PART2)
       (send *ri* :angle-vector-sequence *walk-angle-part2*
             (make-list (length *walk-angle-part2*) :initial-element 600))
       (send *ri* :wait-interpolation)
       (setq *walk-next-part* :PART1))
      )
  )
)

(define-state-executor execute-state-sit :SITTING
  :transition (
    (when (eq *current-state* :STANDING)
      (stand-to-sit))
    (send *ri* :servo-off)
  )
  :persistent ()
)

(define-state-executor execute-state-rotate :STAND_ROTATE
  :transition (
    (unless (eq *current-state* :PAUSED)
      (send *ri* :angle-vector (elt *rotate-angle-part2* 3) 1000)
      (send *ri* :wait-interpolation)
      (setq *rotate-next-part* :PART1)
      )
    )
  :persistent (
    (cond
      ((eq *rotate-next-part* :PART1)
       (send *ri* :angle-vector-sequence *rotate-angle-part1*
             (make-list (length *rotate-angle-part1*) :initial-element 500))
       (send *ri* :wait-interpolation)
       (setq *rotate-next-part* :PART2))

      ((eq *rotate-next-part* :PART2)
       (send *ri* :angle-vector-sequence *rotate-angle-part2*
             (make-list (length *rotate-angle-part2*) :initial-element 500))
       (send *ri* :wait-interpolation)
       (setq *rotate-next-part* :PART1))
      )
  )
)

;; (define-state-executor execute-state-flexion :FLEXION
;;   :transition (
;;     (setq *current-pose-vector* (send *ri* :state :potentio-vector))
;;   )
;;   :persistent (
;;     (let* ((target-joint-names (gethash *target-finger* *finger-joint-map*))
;;            (av (copy-seq *current-pose-vector*))
;;            (command-needed nil)
;;            (all-joints-at-limit t) ;; 全関節が限界か？ (フラグ)
;;            (all-joints-in-error t) ;; 全関節がエラーか？ (フラグ)
;;            )

;;       (dolist (joint-name target-joint-names)
;;         ;; 0番(開閉)ジョイントは除外
;;         (unless (string= (subseq joint-name (- (length joint-name) 1)) "0")
;;           (let ((err (cdr (assoc joint-name servo-state-list :test #'string=)))
;;                 (j-id (position joint-name robot-joint-list
;;                                 :test #'string=
;;                                 :key #'(lambda (j-obj) (send j-obj :name)))))

;;             ;; 1. 関節が正常かチェック
;;             (if (and err (<= err 2) j-id)
;;                 ;; 正常
;;                 (progn
;;                   (setq all-joints-in-error nil) ;; 少なくとも1つは正常
;;                   (let ((curr-angle (aref av j-id)))
;;                     ;; 2. 角度が限界かチェック
;;                     (if (< curr-angle *flex-limit*)
;;                         ;; 限界ではない -> 曲げる
;;                         (progn
;;                           (setq all-joints-at-limit nil) ;; 少なくとも1つは限界でない
;;                           (setq new-angle (min *flex-limit* (+ curr-angle *flex-increment*)))
;;                           (setf (aref av j-id) new-angle)
;;                           (setq command-needed t)
;;                           )
;;                         ;; 限界 (90度) に達している
;;                         t
;;                         )))
;;                 ;; エラー (err > 2 または j-id なし)
;;                 t
;;                 ))))

;;       ;; 3. コマンド送信と状態保持
;;       (when command-needed
;;         (send *ri* :angle-vector av 60)
;;         (setq *current-pose-vector* av) ;; コマンドしたポーズを保存
;;         )

;;       ;; 4. 終了判定
;;       (when (or all-joints-at-limit all-joints-in-error)
;;         (setq *target-state* :PAUSED)
;;         )
;;       ))
;;   )

;; (define-state-executor execute-state-extension :EXTENSION
;;   :transition

;;   :persistant

;;   )

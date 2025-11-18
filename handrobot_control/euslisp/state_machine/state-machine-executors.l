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
  :transition (
    (when *servo-subscriber*
      (ros::ros-info "Unsubscribing from /servo_states")
      (ros::unsubscribe "/servo_states")
      (setq *servo-subscriber* nil))
    )
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
      (send *ri* :angle-vector #f(101.048 48.2963 -19.71 23.1525 -0.33749 48.8363 -39.6562 12.0488 -12.96 53.1563 -41.445 -8.43749 -12.6225 56.43 -41.7487 -16.9425 -1.38374 33.3113 -18.9337) 2000)
      (send *ri* :wait-interpolation)
      )
    )
  :persistent (
    (cond
      ((eq *walk-next-part* :PART1)
       (send *ri* :angle-vector-sequence *walk-angle-part1*
             (make-list (length *walk-angle-part1*) :initial-element 450))
       (send *ri* :wait-interpolation)
       (setq *walk-next-part* :PART2))

      ((eq *walk-next-part* :PART2)
       (send *ri* :angle-vector-sequence *walk-angle-part2*
             (make-list (length *walk-angle-part2*) :initial-element 450))
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
             (make-list (length *rotate-angle-part1*) :initial-element 450))
       (send *ri* :wait-interpolation)
       (setq *rotate-next-part* :PART2))

      ((eq *rotate-next-part* :PART2)
       (send *ri* :angle-vector-sequence *rotate-angle-part2*
             (make-list (length *rotate-angle-part2*) :initial-element 450))
       (send *ri* :wait-interpolation)
       (setq *rotate-next-part* :PART1))
      )
  )
)

(define-state-executor execute-state-flexion :FLEXION
  :transition (
     (setq *servo-state-list* nil)
     (send *ri* :servo-on)
     (unless *servo-subscriber*
       (setq *servo-subscriber* (ros::subscribe "/servo_states" kxr_controller::ServoStateArray #'servo-state-callback)))
     (while (null *servo-state-list*)
       (ros::spin-once)
       (ros::sleep))
     (setq *current-pose-vector* (send *ri* :state :potentio-vector))
  )
  :persistent (
    (let* ((target-joint-names (gethash *target-finger* *finger-joint-map*))
           (av (copy-seq *current-pose-vector*))
           (command-needed nil)
           (all-joints-at-limit t) ;; 全関節が限界か
           (all-joints-in-error t) ;; 全関節がエラーか
           )
      (dolist (joint-name target-joint-names)
        (let ((joint-suffix (subseq joint-name (- (length joint-name) 1))))
          (unless (string= joint-suffix "0")
            (let ((err (cdr (assoc joint-name *servo-state-list* :test #'string=)))
                  (j-id (position joint-name (send *robot* :joint-list)
                                  :test #'string=
                                  :key #'(lambda (j-obj) (send j-obj :name)))))
              ;; 1. 関節が正常かチェック
              (when (and err (<= err 1.6) j-id)
                (setq all-joints-in-error nil)
                (let ((curr-angle (aref av j-id)))
                  ;; 2. 角度が限界かチェック
                  (when (< curr-angle *flex-limit*)
                    (setq all-joints-at-limit nil)
                    (let* ((increment-ratio (cond
                                             ((string= joint-suffix "1") 1.0) ;; 根元: 100%
                                             ((string= joint-suffix "2") 0.8) ;; 中間: 80%
                                             ((string= joint-suffix "3") 0.6) ;; 先端: 60%
                                             (t 1.0)))
                           (increment-amount (* *flex-increment* increment-ratio)))
                      (setq new-angle (min *flex-limit*
                                           (+ curr-angle increment-amount))))
                    (setf (aref av j-id) new-angle)
                    (setq command-needed t))))
              ))))
      ;; 3. コマンド送信と状態保持
      (when command-needed
        (send *ri* :angle-vector av 0.1 :default-controller 0 :min-time 0.1)
        (send *ri* :wait-interpolation)
        (setq *current-pose-vector* av))
      ;; 4. 終了判定
      (when (or all-joints-at-limit all-joints-in-error)
        (send *ri* :cancel-angle-vector)
        (setq *target-state* :PAUSED))
      ))
  )

(define-state-executor execute-state-extension :EXTENSION
  :transition (
    (send *ri* :servo-on)
    (while t
      (setq msg (one-shot-subscribe "/fullbody_controller/servo_on_off_real_interface/state" kxr_controller::ServoOnOff))
      (when (every #'identity (send msg :servo_on_states))
        (return))
      (ros::spin-once)
      (ros::sleep))
    (setq *current-pose-vector* (send *ri* :state :potentio-vector))
    )
  :persistent (
    (let* ((target-joint-names (gethash *target-finger* *finger-joint-map*))
           (av (copy-seq *current-pose-vector*))
           (command-needed nil)
           (all-joints-at-limit t)
           )
      (dolist (joint-name target-joint-names)
        (unless (string= (subseq joint-name (- (length joint-name) 1)) "0")
          (let* ((j-id (position joint-name (send *robot* :joint-list)
                                 :test #'string=
                                 :key #'(lambda (j-obj) (send j-obj :name))))
                 (curr-angle (aref av j-id)))
            (when (> curr-angle *extend-limit*)
              (setq all-joints-at-limit nil)
              (setq new-angle (max *extend-limit*
                                   (- curr-angle *extend-decrement*)))
              (setf (aref av j-id) new-angle)
              (setq command-needed t)))))

      (when command-needed
        (send *ri* :angle-vector av 0.1 :default-controller 0 :min-time 0.1)
        (send *ri* :wait-interpolation)
        (setq *current-pose-vector* av))

      (when all-joints-at-limit
        (send *ri* :cancel-angle-vector)
        (setq *target-state* :PAUSED))
      ))
  )

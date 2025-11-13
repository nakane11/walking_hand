(defvar *state-dispatch-table* (make-hash-table :test 'eq))

;; --- グローバル変数 ---
(defvar *target-state* :SITTING)  ;; 目標の状態 (SIT, STAND, BOW...)
(defvar *current-state* :UNKNOWN) ;; 現在の「持続的」状態 (SIT, STAND)
(defvar *return-state* :SITTING)  ;; アクション完了後に戻る状態

(defmacro define-state-executor (name state-keyword &key transition persistent)
  "状態実行関数を定義し、ディスパッチテーブルに登録するマクロ。"

  ;; 複数の式を評価するため progn で囲む
  `(progn
     ;; A. 関数を定義する
     (defun ,name ()
       ;; 1. 遷移
       (unless (eq *current-state* ,state-keyword)
         (ros::ros-info (format nil "Transition: -> ~A" ,state-keyword))
         (progn ,@transition)
         (ros::ros-info (format nil "Transition: ~A complete." ,state-keyword))
         (setq *current-state* ,state-keyword)
         )
       ;; 2. 持続
       (progn ,@persistent)
       )

     ;; B. ディスパッチテーブルに関数シンボルを登録する
     (setf (gethash ,state-keyword *state-dispatch-table*)
           ',name) ;; 関数名（シンボル）を登録
     ))

(defmacro define-action-executor (name state-keyword &key body)
  "一時的なアクション関数を定義し、ディスパッチテーブルに登録するマクロ。"

  `(progn
     ;; A. 関数を定義する
     (defun ,name ()
       (ros::ros-info (format nil "Action: Executing ~A..." ,state-keyword))
       ;; 1. アクションを実行 (ブロッキング)
       (progn ,@body)
       (ros::ros-info (format nil "Action: ~A finished." ,state-keyword))
       ;; 2. 完了したら、目標状態を *return-state* に戻す
       (setq *target-state* *return-state*)
       (setq *current-state* ,state-keyword)
       )

     ;; B. ディスパッチテーブルに関数シンボルを登録する
     (setf (gethash ,state-keyword *state-dispatch-table*)
           ',name) ;; 関数名（シンボル）を登録
     ))

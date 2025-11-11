(defvar *state-dispatch-table* (make-hash-table :test 'eq))

;; --- グローバル変数 ---
(defvar *target-state* :STANDING)  ;; 目標の状態 (SIT, STAND, BOW...)
(defvar *current-state* :UNKNOWN) ;; 現在の「持続的」状態 (SIT, STAND)
(defvar *return-state* :STANDING)  ;; アクション完了後に戻る状態

(setq *stand-pose* #f(89.6063 2.09251 -35.4375 30.5775 11.5425 74.655 -39.96 -1.07999 0.94501 85.8263 -40.4662 -35.2012 -2.19374 79.0763 -40.4662 -52.515 6.71626 74.3513 -34.83))

(defmacro define-state-executor (name state-keyword &key transition persistent)
  "状態実行関数を定義し、ディスパッチテーブルに登録するマクロ。"

  ;; 複数の式を評価するため progn で囲む
  `(progn
     ;; A. 関数を定義する
     (defun ,name ()
       ;; 1. 遷移
       (unless (eq *current-state* ,state-keyword)
         (progn ,@transition)
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
       ;; 1. アクションを実行 (ブロッキング)
       (progn ,@body)
       ;; 2. 完了したら、目標状態を *return-state* に戻す
       (setq *target-state* *return-state*)
       )

     ;; B. ディスパッチテーブルに関数シンボルを登録する
     (setf (gethash ,state-keyword *state-dispatch-table*)
           ',name) ;; 関数名（シンボル）を登録
     ))

@str = private unnamed_addr constant [22 x i8] c"Hello, LLVM IR World!\00", align 1

; Function Attrs: nofree nounwind uwtable
define dso_local i32 @main(i32 %0, i8** nocapture readnone %1) local_unnamed_addr #0 {
  %3 = tail call i32 @puts(i8* nonnull dereferenceable(1) getelementptr inbounds ([22 x i8], [22 x i8]* @str, i64 0, i64 0))
  ret i32 0
}

; Function Attrs: nofree nounwind
declare i32 @puts(i8* nocapture readonly) local_unnamed_addr #1


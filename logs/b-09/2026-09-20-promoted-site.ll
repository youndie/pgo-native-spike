  %41 = getelementptr inbounds nuw i8, ptr %38, i64 64
  %42 = load ptr, ptr %41, align 8
  %43 = and i32 %40, 328
  %44 = zext nneg i32 %43 to i64
  %45 = getelementptr %struct.InterfaceTableRecord, ptr %42, i64 %44, i32 2
  %46 = load ptr, ptr %45, align 8
  %47 = load ptr, ptr %46, align 8
  %48 = icmp eq ptr %47, @"kfun:S1#area(kotlin.Long){}kotlin.Long"
  br i1 %48, label %if.true.direct_targ.i, label %if.false.orig_indirect.i, !prof !679

if.true.direct_targ.i:                            ; preds = %Kotlin_Array_get.exit
  call void @Kotlin_mm_safePointFunctionPrologue() #162
  %49 = add i64 %acc.1, 1
  br label %"kfun:Shape#area(kotlin.Long){}kotlin.Long.exit"

if.false.orig_indirect.i:                         ; preds = %Kotlin_Array_get.exit
  %50 = call i64 %47(ptr nonnull %33, i64 %acc.1), !prof !680
  br label %"kfun:Shape#area(kotlin.Long){}kotlin.Long.exit"

"kfun:Shape#area(kotlin.Long){}kotlin.Long.exit": ; preds = %if.true.direct_targ.i, %if.false.orig_indirect.i
  %51 = phi i64 [ %50, %if.false.orig_indirect.i ], [ %49, %if.true.direct_targ.i ]

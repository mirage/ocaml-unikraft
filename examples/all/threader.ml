(* SPDX-License-Identifier: MIT
 * Copyright (c) 2025 Samuel Hym, Tarides <samuel@tarides.com>
 *)

let main name =
  Printf.printf "%s: 1\n%!" name;
  for i = 2 to 5 do
    Unix.sleep 1;
    Printf.printf "%s: %d\n%!" name i
  done

let _ =
  let t = Thread.create main "thrd" in
  main "main";
  Thread.join t

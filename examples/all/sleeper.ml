(* SPDX-License-Identifier: MIT
 * Copyright (c) 2025 Samuel Hym, Tarides <samuel@tarides.com>
 *)

let _ =
  Printf.printf "1\n%!";
  for i = 2 to 5 do
    Unix.sleep 1;
    Printf.printf "%d\n%!" i
  done

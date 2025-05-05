(* SPDX-License-Identifier: MIT
 * Copyright (c) 2025 Samuel Hym, Tarides <samuel@tarides.com>
 *)

let _ =
  for i = 0 to Array.length Sys.argv - 1 do
    Printf.printf "Sys.argv.(%d) = %s\n" i Sys.argv.(i)
  done

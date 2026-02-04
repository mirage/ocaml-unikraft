external unsafe_use_stack : int -> unit = "use_large_buffer"

let _ =
  Printf.printf "Hello before using much stack space\n%!";
  unsafe_use_stack 65536;
  Printf.printf "Bye after using much stack space\n%!"

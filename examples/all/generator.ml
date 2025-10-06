(* SPDX-License-Identifier: MIT
 * Copyright (c) 2025 Samuel Hym, Tarides <samuel@tarides.com>
 *)

(* A small generator for:
   - dune.inc
   - Firecracker configurations
   - how to call QEMU *)

let pr fmt out entries = List.iter (Printf.fprintf out fmt) entries

let print_dune_one_test test extralibs extraargs exitcodes =
  let concat fmt out entries =
    match entries with
    | [] -> ()
    | e :: entries ->
        Printf.fprintf out fmt e;
        pr (" " ^^ fmt) out entries
  in
  let qemu_args out args =
    match args with
    | [] -> ()
    | _ -> Printf.fprintf out {|
    -append
    "%a"|} (concat "%s") args
  in
  Printf.printf
    {|(executable
 (name %s)
 (flags
  :standard
  (:include "flags"))
 (libraries unikraftstartup%a))

(rule
 (alias test-%s)
 (enabled_if
  (and
   (= %%{context_name} unikraft)
   (= %%{env:UNIKRAFTBACKEND=qemu} qemu)))
 (action
  (with-accepted-exit-codes
   %s
   (run
    %%{read-lines:qemu-call}
    -nographic
    -nodefaults
    -serial
    stdio
    -netdev
    user,id=n0,restrict=on
    -device
    virtio-net-pci,netdev=n0
    -kernel
    %%{dep:%s.exe}%a))))

(rule
 (with-stdout-to
  %s_fcvm_config.json
  (run ./generator.exe fcconfig %s%a)))

(rule
 (alias test-%s)
 (enabled_if
  (and
   (= %%{context_name} unikraft)
   (= %%{env:UNIKRAFTBACKEND=qemu} firecracker)
   %%{bin-available:firecracker}))
 (deps
  %s.exe
  (:config %s_fcvm_config.json))
 (action
  (run firecracker --no-api --config-file %%{config})))

(alias
 (name runtest)
 (deps
  (alias test-%s)))

|}
    test (pr " %s") extralibs test
    (match exitcodes with
    | None ->
        {|(or
    0
    83
    ; 83: Unikraft successful exit with ISA debug
    )|}
    | Some exitcodes -> exitcodes)
    test qemu_args extraargs test test (pr " %S") extraargs test test test test

let gen_dune () =
  print_dune_one_test "hello" [] [] None;
  print_dune_one_test "sleeper" [ "unix" ] [] None;
  print_dune_one_test "threader" [ "unix"; "threads" ] [] None;
  print_dune_one_test "args" [] [ "arg1"; "arg2"; "arg3"; "arg4" ] None;
  (* Unfortunately, I see many crashing unikernels nevertheless reported as
     returning 83 *)
  print_dune_one_test "fail" [] [] (Some "(or 0 83 85)")

let gen_firecracker_config () =
  let test = Sys.argv.(2) and args = Array.to_list Sys.argv |> List.drop 3 in
  Printf.printf
    {|{
  "boot-source": {
    "kernel_image_path": "%s.exe",
    "boot_args": "%s.exe%a",
    "initrd_path": null
  },
  "drives": [],
  "machine-config": {
    "vcpu_count": 1,
    "mem_size_mib": 32,
    "smt": false,
    "track_dirty_pages": false,
    "huge_pages": "None"
  },
  "cpu-config": null,
  "balloon": null,
  "network-interfaces": [],
  "vsock": null,
  "logger": null,
  "metrics": null,
  "mmds-config": null,
  "entropy": null
}
|}
    test test (pr " %s") args

let gen_qemu_call target =
  let pr = List.iter print_endline in
  let same_arch = Config.architecture = target
  and force_emulation = Sys.getenv_opt "CI" = Some "true" in
  (match target with
  | "amd64" -> pr [ "qemu-system-x86_64"; "-device"; "isa-debug-exit" ]
  | "arm64" -> pr [ "qemu-system-aarch64" ]
  | _ -> failwith ("Unsupported target architecture: " ^ target));
  match (target, same_arch, force_emulation) with
  | "amd64", true, false | "arm64", true, false ->
      pr [ "-cpu"; "host"; "--enable-kvm" ]
  | "amd64", _, _ ->
      pr
        [
          "-machine";
          "q35";
          "-cpu";
          "qemu64,-vmx,-svm,+pdpe1gb,+rdrand,+rdseed";
          (* The x2apic feature appears in the options used by Unikraft to
             launch QEMU, but it is not supported in CI and not used in our
             simple examples so it isn’t enabled here *)
        ]
  | "arm64", _, _ -> pr [ "-machine"; "virt"; "-cpu"; "cortex-a72" (* "max" *) ]
  | _ -> assert false (* as we would have failed before *)

let usage () =
  let me = Sys.argv.(0) in
  Printf.printf
    {|%s dune.inc
%s fcconfig <test> [args...]
%s qemu-call <targetarch>
|} me me me;
  exit 1

let _ =
  match Sys.argv.(1) with
  | "dune.inc" -> gen_dune ()
  | "fcconfig" ->
      if Array.length Sys.argv < 3 then usage () else gen_firecracker_config ()
  | "qemu-call" ->
      if Array.length Sys.argv < 3 then usage () else gen_qemu_call Sys.argv.(2)
  | _ | (exception Invalid_argument _) -> usage ()

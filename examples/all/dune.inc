(executable
 (name hello)
 (flags
  :standard
  (:include "flags"))
 (libraries unikraftstartup))

(rule
 (alias runtest)
 (enabled_if
  (and
   (= %{context_name} unikraft)
   (= %{env:UNIKRAFTBACKEND=qemu} qemu)))
 (action
  (with-accepted-exit-codes
   (or
    0
    83
    ; 83: Unikraft successful exit with ISA debug
    )
   (run
    %{read-lines:qemu-call}
    -nographic
    -nodefaults
    -serial
    stdio
    -netdev
    user,id=n0,restrict=on
    -device
    virtio-net-pci,netdev=n0
    -kernel
    %{dep:hello.exe}))))

(rule
 (with-stdout-to
  hello_fcvm_config.json
  (run ./generator.exe fcconfig hello)))

(rule
 (alias runtest)
 (enabled_if
  (and
   (= %{context_name} unikraft)
   (= %{env:UNIKRAFTBACKEND=qemu} firecracker)
   %{bin-available:firecracker}))
 (deps
  hello.exe
  (:config hello_fcvm_config.json))
 (action
  (run firecracker --no-api --config-file %{config})))

(executable
 (name sleeper)
 (flags
  :standard
  (:include "flags"))
 (libraries unikraftstartup unix))

(rule
 (alias runtest)
 (enabled_if
  (and
   (= %{context_name} unikraft)
   (= %{env:UNIKRAFTBACKEND=qemu} qemu)))
 (action
  (with-accepted-exit-codes
   (or
    0
    83
    ; 83: Unikraft successful exit with ISA debug
    )
   (run
    %{read-lines:qemu-call}
    -nographic
    -nodefaults
    -serial
    stdio
    -netdev
    user,id=n0,restrict=on
    -device
    virtio-net-pci,netdev=n0
    -kernel
    %{dep:sleeper.exe}))))

(rule
 (with-stdout-to
  sleeper_fcvm_config.json
  (run ./generator.exe fcconfig sleeper)))

(rule
 (alias runtest)
 (enabled_if
  (and
   (= %{context_name} unikraft)
   (= %{env:UNIKRAFTBACKEND=qemu} firecracker)
   %{bin-available:firecracker}))
 (deps
  sleeper.exe
  (:config sleeper_fcvm_config.json))
 (action
  (run firecracker --no-api --config-file %{config})))

(executable
 (name threader)
 (flags
  :standard
  (:include "flags"))
 (libraries unikraftstartup unix threads))

(rule
 (alias runtest)
 (enabled_if
  (and
   (= %{context_name} unikraft)
   (= %{env:UNIKRAFTBACKEND=qemu} qemu)))
 (action
  (with-accepted-exit-codes
   (or
    0
    83
    ; 83: Unikraft successful exit with ISA debug
    )
   (run
    %{read-lines:qemu-call}
    -nographic
    -nodefaults
    -serial
    stdio
    -netdev
    user,id=n0,restrict=on
    -device
    virtio-net-pci,netdev=n0
    -kernel
    %{dep:threader.exe}))))

(rule
 (with-stdout-to
  threader_fcvm_config.json
  (run ./generator.exe fcconfig threader)))

(rule
 (alias runtest)
 (enabled_if
  (and
   (= %{context_name} unikraft)
   (= %{env:UNIKRAFTBACKEND=qemu} firecracker)
   %{bin-available:firecracker}))
 (deps
  threader.exe
  (:config threader_fcvm_config.json))
 (action
  (run firecracker --no-api --config-file %{config})))

(executable
 (name args)
 (flags
  :standard
  (:include "flags"))
 (libraries unikraftstartup))

(rule
 (alias runtest)
 (enabled_if
  (and
   (= %{context_name} unikraft)
   (= %{env:UNIKRAFTBACKEND=qemu} qemu)))
 (action
  (with-accepted-exit-codes
   (or
    0
    83
    ; 83: Unikraft successful exit with ISA debug
    )
   (run
    %{read-lines:qemu-call}
    -nographic
    -nodefaults
    -serial
    stdio
    -netdev
    user,id=n0,restrict=on
    -device
    virtio-net-pci,netdev=n0
    -kernel
    %{dep:args.exe}
    -append
    "arg1 arg2 arg3 arg4"))))

(rule
 (with-stdout-to
  args_fcvm_config.json
  (run ./generator.exe fcconfig args "arg1" "arg2" "arg3" "arg4")))

(rule
 (alias runtest)
 (enabled_if
  (and
   (= %{context_name} unikraft)
   (= %{env:UNIKRAFTBACKEND=qemu} firecracker)
   %{bin-available:firecracker}))
 (deps
  args.exe
  (:config args_fcvm_config.json))
 (action
  (run firecracker --no-api --config-file %{config})))

(executable
 (name fail)
 (flags
  :standard
  (:include "flags"))
 (libraries unikraftstartup))

(rule
 (alias runtest)
 (enabled_if
  (and
   (= %{context_name} unikraft)
   (= %{env:UNIKRAFTBACKEND=qemu} qemu)))
 (action
  (with-accepted-exit-codes
   (or 0 83 85)
   (run
    %{read-lines:qemu-call}
    -nographic
    -nodefaults
    -serial
    stdio
    -netdev
    user,id=n0,restrict=on
    -device
    virtio-net-pci,netdev=n0
    -kernel
    %{dep:fail.exe}))))

(rule
 (with-stdout-to
  fail_fcvm_config.json
  (run ./generator.exe fcconfig fail)))

(rule
 (alias runtest)
 (enabled_if
  (and
   (= %{context_name} unikraft)
   (= %{env:UNIKRAFTBACKEND=qemu} firecracker)
   %{bin-available:firecracker}))
 (deps
  fail.exe
  (:config fail_fcvm_config.json))
 (action
  (run firecracker --no-api --config-file %{config})))


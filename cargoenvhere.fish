function cargoenvhere -d "Image with `cargo` as a virtual environment in the current dir"
  # optional arguments for PATH saved into a temp file and executed in entrypoint 
  set temp_file (mktemp)
  echo -e '#!/bin/bash\nexport PATH="/cache/cargo/bin/:$PATH"\n\nexec "$@"' > $temp_file
  chmod +x $temp_file

  set dirname (basename (pwd))

  echo "Image with `cargo` as a virtual environment in the current" (pwd) "dir"
  mkdir -p $HOME/cache/$dirname
  docker run --rm -it -w /shellhere/$dirname \
    -v "$temp_file:/setenv.sh" \
    --entrypoint /setenv.sh \
    -v (pwd):/shellhere/$dirname \
    -v $HOME/code/cache/$dirname/:/cache/ \
    -e CARGO_TARGET_DIR=/cache/target/ \
    -e CARGO_HOME=/cache/cargo/ \
    -e SCCACHE_DIR=/cache/sccache/ \
    $argv
end

# example usage
# cargoenvhere docker.io/paritytech/ci-linux:production /bin/bash -c "\
#   CARGO_INCREMENTAL=0 \
#   RUSTFLAGS='-Cinstrument-coverage -Cdebug-assertions=y -Dwarnings' \
#   LLVM_PROFILE_FILE='cargo-test-%p-%m.profraw' \
#   time cargo test --workspace --profile testnet --verbose --locked --features=runtime-benchmarks,runtime-metrics,try-runtime"

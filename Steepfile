D = Steep::Diagnostic

target :lib do
  signature "sig"

  check "lib"

  library "pathname"
  library "fileutils"
  library "tmpdir"
  library "forwardable"

  configure_code_diagnostics(D::Ruby.lenient)
end

target :test do
  signature "sig", "sig-private"

  check "test"
end

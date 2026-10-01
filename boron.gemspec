require_relative "lib/boron/version"

Gem::Specification.new do |spec|
  spec.name = "boron"
  spec.version = Boron::VERSION
  spec.authors = ["Jack Willis"]
  spec.email = ["jack@attac.us"]
  spec.summary = "A Lisp hosted on Ruby"
  spec.description = "An experimental Lisp compiler with lexical functions, Ruby interop, and inspectable generated Ruby."
  spec.license = "MIT"
  spec.homepage = "https://github.com/jackwillis/boron"
  spec.metadata["source_code_uri"] = spec.homepage
  spec.required_ruby_version = ">= 3.3"

  spec.files = Dir.chdir(__dir__) do
    Dir["lib/**/*.{rb,bn}", "bin/boron", "examples/*.{bn,json}", "LICENSE", "README.md", "LANGUAGE.md", "DESIGN.md"].sort
  end
  spec.bindir = "bin"
  spec.executables = ["boron"]
  spec.require_paths = ["lib"]
end

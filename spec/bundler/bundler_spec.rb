# encoding: utf-8
require "spec_helper"
require "bundler"

describe Bundler do
  describe "version 1.99" do
    context "when bundle is run" do
      it "should print a single deprecation warning" do
        # install_gemfile calls `bundle :install, opts`
        install_gemfile <<-G
          source "file://#{gem_repo1}"
          gem "rack"
        G

        expect(out).to include("DEPRECATION: Gemfile and Gemfile.lock are " \
         "deprecated and will be replaced with gems.rb and gems.locked in " \
         "Bundler 2.0.0.")
        expect(err).to lack_errors
      end
    end

    context "when Bundler.setup is run in a ruby script" do
      it "should print a single deprecation warning" do
        install_gemfile <<-G
          source "file://#{gem_repo1}"
          gem "rack", :group => :test
        G

        ruby <<-RUBY
          require 'rubygems'
          require 'bundler'
          require 'bundler/vendored_thor'

          Bundler.ui = Bundler::UI::Shell.new
          Bundler.setup
          Bundler.setup
        RUBY

        expect(out).to eq("DEPRECATION: Gemfile and Gemfile.lock are " \
         "deprecated and will be replaced with gems.rb and gems.locked in " \
         "Bundler 2.0.0.")
        expect(err).to lack_errors
      end
    end

    context "when `bundler/deployment` is required in a ruby script" do
      it "should print a capistrano deprecation warning" do
        install_gemfile <<-G
          source "file://#{gem_repo1}"
          gem "rack", :group => :test
        G

        ruby(<<-RUBY, { :expect_err => true })
          require 'bundler/deployment'
        RUBY

        expect(err).to include("DEPRECATION: Bundler no longer integrates " \
                               "with Capistrano, but Capistrano provides " \
                               "its own integration with Bundler via the " \
                               "capistrano-bundler gem. Use it instead.")
        expect(err).to lack_errors
      end
    end
  end

  describe "#load_gemspec_uncached" do
    let(:app_gemspec_path) { tmp("test.gemspec") }
    subject { Bundler.load_gemspec_uncached(app_gemspec_path) }

    context "with incorrect YAML file" do
      before do
        File.open(app_gemspec_path, "wb") do |f|
          f.write strip_whitespace(<<-GEMSPEC)
            ---
              {:!00 ao=gu\g1= 7~f
          GEMSPEC
        end
      end

      it "catches YAML syntax errors" do
        expect { subject }.to raise_error(Bundler::GemspecError)
      end

      context "on Rubies with a settable YAML engine", :if => defined?(YAML::ENGINE) do
        context "with Syck as YAML::Engine" do
          it "raises a GemspecError after YAML load throws ArgumentError" do
            orig_yamler, YAML::ENGINE.yamler = YAML::ENGINE.yamler, "syck"

            expect { subject }.to raise_error(Bundler::GemspecError)

            YAML::ENGINE.yamler = orig_yamler
          end
        end

        context "with Psych as YAML::Engine" do
          it "raises a GemspecError after YAML load throws Psych::SyntaxError" do
            orig_yamler, YAML::ENGINE.yamler = YAML::ENGINE.yamler, "psych"

            expect { subject }.to raise_error(Bundler::GemspecError)

            YAML::ENGINE.yamler = orig_yamler
          end
        end
      end
    end

    context "with correct YAML file", :if => defined?(Encoding) do
      it "can load a gemspec with unicode characters with default ruby encoding" do
        # spec_helper forces the external encoding to UTF-8 but that's not the
        # default until Ruby 2.0
        verbose, $VERBOSE = $VERBOSE, false
        encoding, Encoding.default_external = Encoding.default_external, "ASCII"
        $VERBOSE = verbose

        File.open(app_gemspec_path, "wb") do |file|
          file.puts <<-GEMSPEC.gsub(/^\s+/, "")
            # -*- encoding: utf-8 -*-
            Gem::Specification.new do |gem|
              gem.author = "André the Giant"
            end
          GEMSPEC
        end

        expect(subject.author).to eq("André the Giant")

        verbose, $VERBOSE = $VERBOSE, false
        Encoding.default_external = encoding
        $VERBOSE = verbose
      end
    end
  end
end

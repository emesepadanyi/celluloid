RSpec.describe Celluloid::Internals::CPUCounter do
  describe "#cores" do
    subject { described_class.cores }

    let(:num_cores) { 1024 }

    before do
      allow(described_class).to receive(:`) { raise "backtick stub called" }
      allow(::IO).to receive(:open).and_raise("IO.open stub called!")
      described_class.instance_variable_set(:@cores, nil)
    end

    after do
      ENV["NUMBER_OF_PROCESSORS"] = nil
      described_class.instance_variable_set(:@cores, nil)
    end

    context "with from_env" do
      context "valid env value" do
        before { ENV["NUMBER_OF_PROCESSORS"] = num_cores.to_s }
        it { is_expected.to eq num_cores }
      end

      context "invalid env value" do
        before { ENV["NUMBER_OF_PROCESSORS"] = "" }
        subject { described_class.from_env }
        it { is_expected.to be nil }
      end
    end

    context "with from_sysdev" do
      subject { described_class.from_sysdev }

      context "when /sys/devices/system/cpu/present exists" do
        before do
          expect(::IO).to receive(:read).with("/sys/devices/system/cpu/present")
                                        .and_return("dunno-whatever-#{num_cores - 1}")
        end
        it { is_expected.to eq num_cores }
      end

      context "when /sys/devices/system/cpu/present does NOT exist" do
        before do
          expect(::IO).to receive(:read).with("/sys/devices/system/cpu/present")
                                        .and_raise(Errno::ENOENT)
        end

        context "when /sys/devices/system/cpu/cpu* files exist" do
          before do
            cpu_entries = (1..num_cores).map { |n| "cpu#{n}" }
            cpu_entries << "non-cpu-entry-to-ignore"
            expect(Dir).to receive(:[]).with("/sys/devices/system/cpu/cpu*")
                                       .and_return(cpu_entries)
          end
          it { is_expected.to eq num_cores }
        end

        context "when /sys/devices/system/cpu/cpu* files DO NOT exist" do
          before do
            expect(Dir).to receive(:[]).with("/sys/devices/system/cpu/cpu*")
                                       .and_return([])
          end

          it { is_expected.to be nil }
        end
      end
    end

    context "with from_java" do
      subject { described_class.from_java }
      context "when Java::Java is defined" do
        let(:java_cores) { 88 }

        before do
          stub_const("Java::Java", double)
          allow(Java::Java).to receive_message_chain(:lang, :Runtime, :getRuntime, :availableProcessors).and_return java_cores
        end

        it { is_expected.to eq java_cores }
      end

      context "when Java::Java is not defined" do
        it { is_expected.to eq nil }
      end
    end

    context "with from_proc" do
      subject { described_class.from_proc }
      context "when file exists" do
        before do
          allow(File).to receive(:exist?).and_call_original
          expect(File).to receive(:exist?).with("/proc/cpuinfo").and_return(true)
          expect(File).to receive(:read).with("/proc/cpuinfo").and_return("processor\t: tm2 jjgfjhjdffhjfnkjdsse3 c\nprocessor\t:")
        end

        it { is_expected.to eq 2}
      end

      context "when file does not exist" do
        before do
          allow(File).to receive(:exist?).and_call_original
          expect(File).to receive(:exist?).with("/proc/cpuinfo").and_return(false)
        end

        it { is_expected.to eq nil }
      end
    end

    context "with from_win32ole" do
      subject { described_class.from_win32ole }
      context "win32ole already imported" do
        let(:win_cores) { 99 }

        before do
          stub_const("WIN32OLE", double)
          allow(WIN32OLE).to receive_message_chain(:connect, :ExecQuery, :NumberOfProcessors).and_return win_cores
        end

        it { is_expected.to eq win_cores }
      end

      context "without win32ole" do
        it { is_expected.to eq nil }
      end
    end

    context "with from_sysctl" do
      subject { described_class.from_sysctl }

      context "when sysctl blows up" do
        before { allow(described_class).to receive(:`).and_raise(Errno::EINTR) }
        it { is_expected.to be nil }
      end

      context "when sysctl fails" do
        before { allow(described_class).to receive(:`).and_return(`false`) }
        it { is_expected.to be nil }
      end

      context "when sysctl succeeds" do
        before do
          expect(described_class).to receive(:`).with("sysctl -n hw.ncpu 2>/dev/null")
                                                .and_return(num_cores.to_s)
        end

        it { is_expected.to eq num_cores }
      end
    end

    context "with from_result" do
      context "when passed a symbol" do
        subject { described_class.from_result(:foo) }
        it { is_expected.to be nil }
      end
      context "when passed 0" do
        subject { described_class.from_result(0) }
        it { is_expected.to be nil }
      end
      context "when passed valid integer" do
        subject { described_class.from_result(num_cores) }
        it { is_expected.to be num_cores }
      end
    end

    describe "#count_cores" do
      subject { described_class.count_cores }
      before do
        allow(described_class).to receive(:from_env).and_return(nil)
        allow(described_class).to receive(:from_sysdev).and_return(nil)
        allow(described_class).to receive(:from_java).and_return(nil)
        allow(described_class).to receive(:from_proc).and_return(nil)
        allow(described_class).to receive(:from_win32ole).and_return(nil)
        allow(described_class).to receive(:from_sysctl).and_return(nil)
      end

      context "when all tries fail" do
        it { is_expected.to eq 1}
      end

      context "when one method works" do
        let(:cores) { 60 }
        before do
          expect(described_class).to receive(:from_java).once.and_return(cores)
          expect(described_class).not_to receive(:from_proc)
        end

        it { is_expected.to eq cores}
      end
    end
  end
end

require 'spec_helper'

describe Gush::Worker do
  let(:workflow)    { TestWorkflow.create }
  let(:job)         { workflow.find_job("Prepare")  }
  let(:config)      { client.configuration.to_json  }

  before :each do
    allow(client).to receive(:find_workflow).with(workflow.id).and_return(workflow)
    allow(Gush::Client).to receive(:new).and_return(client)
  end

  describe "#perform" do
    context "when job fails" do
      before :each do
        expect(job).to receive(:work).and_raise(StandardError)
        job.enqueue!
        job.start!
      end

      it "should mark it as failed" do
        allow(client).to receive(:persist_job)
        Gush::Worker.new.perform(workflow.id, "Prepare", config)

        expect(client).to have_received(:persist_job).with(workflow.id, job).at_least(1).times do |_, job|
          expect(job).to be_failed
        end

      end

      it "reports that job failed" do
        allow(client).to receive(:worker_report)
        Gush::Worker.new.perform(workflow.id, "Prepare", config)
        expect(client).to have_received(:worker_report).with(hash_including(status: :failed))
      end
    end

    context "when job completes successfully" do
      it "should mark it as succedeed" do
        allow(client).to receive(:persist_job)

        Gush::Worker.new.perform(workflow.id, "Prepare", config)

        expect(client).to have_received(:persist_job).at_least(1).times.with(workflow.id, job) do |_, job|
          expect(job).to be_succeeded
        end
      end

      it "reports that job succedeed" do
        allow(client).to receive(:worker_report)
        Gush::Worker.new.perform(workflow.id, "Prepare", config)

        expect(client).to have_received(:worker_report).with(hash_including(status: :finished))
      end
    end

    it "calls job.work method" do
      expect(job).to receive(:work)
      Gush::Worker.new.perform(workflow.id, "Prepare", config)
    end

    it "reports when the job is started" do
      allow(client).to receive(:worker_report)
      Gush::Worker.new.perform(workflow.id, "Prepare", config)
      expect(client).to have_received(:worker_report).with(hash_including(status: :started))
    end
  end
end

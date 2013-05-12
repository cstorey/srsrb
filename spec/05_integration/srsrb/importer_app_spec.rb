require 'srsrb/importer_app'
require 'review_browser'
require 'rack/test'

module SRSRB
  describe ImporterApp do
    include Rack::Test::Methods
    let (:import_parser) { mock :anki_import_parser }
    let (:plain_app) { ImporterApp.new import_parser }
    let (:app) { plain_app.into { |app| Rack::Session::Pool.new app }.into { |app| Rack::CommonLogger.new app, $stderr } }
    let (:browser) { ReviewBrowser.new app }

    let (:hangul_anki) {  Pathname.new(__FILE__).dirname.join('../../data/Hangul.anki') }

    before do
      described_class.set :raise_errors, true
      described_class.set :dump_errors, true
      described_class.set :show_exceptions, false
    end

    describe "GET /import/" do
      it "should be 200" do
        get '/import/'
        expect(last_response).to be_ok
      end

      let (:deck_file_size) { hangul_anki.stat.size }
      let (:deck_md5sum) { Digest::MD5.hexdigest(hangul_anki.read) }
      it "should allow uploading an anki deck" do
        importer = browser.get_import_page
        import_parser.should_receive(:accept_upload) do |stream|
          data = stream.read
          expect(data.size).to be == deck_file_size
          expect(Digest::MD5.hexdigest(data)).to be == deck_md5sum
        end
        importer.upload hangul_anki, true
      end

      it "should show a happy message if all goes well" do
        import_parser.stub(:accept_upload)
        result = browser.get_import_page.upload hangul_anki, true
        expect(result).to have_at_least(1).successes
      end

      it "should redirect back to the same page if no file is specified" do
        post '/import/'
        expect(last_response).to be_redirect
      end
      it "should show an error if no file is specified" do
        result = browser.get_import_page.upload nil, true
        expect(result).to have_at_least(1).errors
      end
    end
  end
end

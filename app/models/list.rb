class List < ActiveRecord::Base
  has_and_belongs_to_many :environments
  has_many :jobs
  validates :name, :presence => true
  validates_uniqueness_of :name
  default_scope :order => 'name'
  scope :active, where(:deleted_at => nil)
  validate :list_exists

  if $oats['execution']['occ']['results_webserver']
    ResultsServer = 'http://' + $oats['execution']['occ']['results_webserver']
  else
    ResultsServer = 'http://' + $oats['execution']['occ']['server_host']
  end

  def list_exists
    test_count(true) unless name == ''
  end

  def jobtest_with_testid(testid)
    Jobtest.first :joins => [:job, :bug ],
      :readonly => false,
      :conditions => {'jobs.list_id' => self.id,
      'bugs.deleted_at' => nil,
      'jobtests.deleted_at' => nil, 'jobtests.testid' => testid }
  end

  def List.url(name)
    nam, extension = List.name_extension(name)
    path = TestData.locate(nam)
    path ? ResultsServer + path.sub(/.*(\/oats\/tests\/.*)/,'\1') : nil
  end

  def url
    List.url(self.name)
  end

  def List.test_info(tst_id)
    yaml = {}
    file = File.join($oats['execution']['dir_tests'], tst_id, 'info.yml')
    if File.exist?(file)
      yaml = YAML.load_file(file)
    else
      file = File.join($oats['execution']['dir_tests'], tst_id)
      file = Dir.glob(File.join(file,'/*.rb')).first if tst_id !~ /.rb$/
      if file and File.exist?(file)
        cnt = 0
        IO.foreach(file) do |line|
          %w(author created last_modified description).each do |attr|
            yaml[attr] = line.sub(/.*#{attr}:\s*/,'') if line =~ /^#\s*#{attr}:/
          end
          break if (cnt += 1) == 5
        end
      end
    end
    return yaml
  end

  def List.test_url(tst)
    case tst
    when /\//
      tst_url = ResultsServer + '/oats/tests/' + tst
    when /.txt$/
      tst_url = List.url(tst)
    else
      return nil
    end
    return tst_url
  end

  def test_count(is_refresh = false)
    testfiles(is_refresh).size
  end


  # Returns array of tests or an error string
  def testfiles(is_refresh = false)
    return @test_files if @test_files and not is_refresh
    @test_files, error_array = List.testfiles(self.name)
    error_array.each {|e| errors.add('Name:',e)}
    return @test_files
  end

  def List.testfiles(name)
    nam, extension = List.name_extension(name)
    errs = []
    tests_array = []
    begin
      file = TestData.locate(nam)
      raise "Can not locate test #{nam}" unless file
      case extension
      when 'yml'
        yaml = YAML.load_file(file)
        tests_array = yaml['execution'] ? yaml['execution']['test_files'] : []
      when 'txt'
        tests_array = TestList.txt_tests(file)
      else
        raise "Extension for #{nam} has to be yml or txt"
      end
      tests_array.each do |tst|
        next unless tst =~ /.txt$/
        tests_array.delete tst
        add_tests, add_errs = List.testfiles(tst)
        tests_array = add_tests + tests_array
        errs = add_errs + errs
      end
    rescue Exception => e
      errs.push e.to_s
      Rails.logger.warn e.to_s
    end
    return tests_array, errs
  end

  def List.name_extension(nam)
    extension = nam.sub(/.*\./,'')
    if extension == nam
      extension = 'yml'
      nam += "." + extension
    end
    return nam, extension
  end

end

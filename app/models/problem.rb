class Problem < ActiveRecord::Base
  attr_accessible :created_date, :is_public, :last_used, :rendered_text, :text, :json, :problem_type
  has_and_belongs_to_many :tags
  belongs_to :instructor
  has_and_belongs_to_many :collections
  belongs_to :previous_version, class_name: 'Problem'


  scope :is_public, -> { where(is_public:  true) }
  scope :last_used, ->(t) { where(last_used: t) }
  scope :instructor_id, ->(id) { where(instructor_id: id) }


  searchable do
    integer   :id
    text      :text
    text      :json
    integer   :instructor_id
    boolean   :is_public
    time      :last_used
    time      :updated_at
    string    :problem_type
    time      :created_date

    string    :tag_names, :multiple => true do
      tags.map(&:name)
    end
    integer :collection_ids, :multiple => true do
      collections.map(&:id)
    end
  end

  def self.all_problem_types
    {'Dropdown' => 'Dropdown', 'FillIn' => 'Fill-in', 
      'MultipleChoice' => 'Multiple choice', 'SelectMultiple' => 'Select multiple', 
      'TrueFalse' => 'True/False'}
  end
  
  def self.sort_by_options
    ['Relevancy', 'Date Created', 'Last Used']
  end

  def html5
    if rendered_text
      return rendered_text
    end

    if json and !json.empty?
      question = Question.from_JSON(self.json)
      quiz = Quiz.new("", :questions => [question])
      quiz.render_with("Html5", {'template' => 'preview.html.erb'})
      self.update_attributes(:rendered_text => quiz.output)
      quiz.output
    else
      'This question could not be displayed (no JSON found)'
    end
  end

  def self.filter(user, filters)
    problems = Problem.search do
      any_of do
        with(:instructor_id, user.id)
        with(:is_public, true)
      end

      filters[:tags].each do |tag|
        with(:tag_names, tag)
      end

      if !filters[:problem_type].empty?
        any_of do
          filters[:problem_type].each do |sort_param|
            with(:problem_type, sort_param)
          end
        end
      end

      if !filters[:collections].empty?
        any_of do
          filters[:collections].each do |col|
            with(:collection_ids, col)
          end
        end
      end

      fulltext filters[:search]
      
      if filters[:sort_by] == 'Relevancy'
        order_by(:score, :desc)
      elsif filters[:sort_by] == 'Date Created'
        order_by(:created_date, :desc)
      elsif filters[:sort_by] == 'Last Used'
        order_by(:last_used, :desc)
      end
      
      paginate :page => filters['page'], :per_page => filters['per_page']
    end

    problems.results
  end
  
  def add_tag(tag_name)
    return false if tags.find_by_name(tag_name)
    
    tags << (Tag.where(name: tag_name)[0] || Tag.create(name: tag_name))
    save
    return true
  end
  
  def remove_tag(tag_name)
    tag = tags.find_by_name(tag_name)
    tags.delete(tag) if tag
    save
  end
  
  def add_tags(tag_names)
    tag_names.select{ |tag| add_tag tag }.map{ |tag| Tag.where(:name => tag)[0] }
  end
end

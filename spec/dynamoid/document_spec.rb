# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::Document do
  it 'initializes a new document' do
    address = Address.new

    expect(address.new_record).to be_truthy
    expect(address.attributes).to eq({})
  end

  it 'responds to will_change! methods for all fields' do
    address = Address.new
    expect(address).to respond_to(:id_will_change!)
    expect(address).to respond_to(:options_will_change!)
    expect(address).to respond_to(:created_at_will_change!)
    expect(address).to respond_to(:updated_at_will_change!)
  end

  it 'initializes a new document with attributes' do
    address = Address.new(city: 'Chicago')

    expect(address.new_record).to be_truthy

    expect(address.attributes).to eq(city: 'Chicago')
  end

  it 'initializes a new document with a virtual attribute' do
    address = Address.new(zip_code: '12345')

    expect(address.new_record).to be_truthy

    expect(address.attributes).to eq(city: 'Chicago')
  end

  it 'allows interception of write_attribute on load' do
    klass = new_class do
      field :city

      def city=(value)
        self[:city] = value.downcase
      end
    end
    expect(klass.new(city: 'Chicago').city).to eq 'chicago'
  end

  it 'ignores unknown fields (does not raise error)' do
    klass = new_class do
      field :city
    end

    model = klass.new(unknown_field: 'test', city: 'Chicago')
    expect(model.city).to eql 'Chicago'
  end

  describe '#initialize' do
    describe 'type casting' do
      let(:klass) do
        new_class do
          field :count, :integer
        end
      end

      it 'type casts attributes' do
        obj = klass.new(count: '101')
        expect(obj.attributes[:count]).to eql(101)
      end
    end
  end

  describe '.create' do
    let(:klass) do
      new_class do
        field :city
      end
    end

    it 'creates a new document' do
      address = klass.create(city: 'Chicago')

      expect(address.new_record).to eql false
      expect(address.id).to be_present

      address_saved = klass.find(address.id)
      expect(address_saved.city).to eq('Chicago')
    end

    it 'creates multiple documents' do
      addresses = klass.create([{ city: 'Chicago' }, { city: 'New York' }])

      expect(addresses.size).to eq 2
      expect(addresses).to be_all(&:persisted?)
      expect(addresses[0].city).to eq 'Chicago'
      expect(addresses[1].city).to eq 'New York'
    end

    describe 'validation' do
      let(:klass_with_validation) do
        new_class do
          field :name
          validates :name, length: { minimum: 4 }
        end
      end

      it 'does not save invalid model' do
        obj = klass_with_validation.create(name: 'Theodor')
        expect(obj).to be_persisted

        obj = klass_with_validation.create(name: 'Mo')
        expect(obj).not_to be_persisted
      end

      it 'saves valid models even if there are invalid' do
        obj1, obj2 = klass_with_validation.create([{ name: 'Theodor' }, { name: 'Mo' }])

        expect(obj1).to be_persisted
        expect(obj2).not_to be_persisted
      end
    end

    it 'works with a HashWithIndifferentAccess argument' do
      attrs = ActiveSupport::HashWithIndifferentAccess.new(city: 'Atlanta')
      obj = klass.create(attrs)

      expect(obj).to be_persisted
      expect(obj.city).to eq 'Atlanta'
    end

    it 'creates table if it does not exist' do
      expect {
        klass.create(city: 'Chicago')
      }.to change {
        tables_created.include?(klass.table_name)
      }.from(false).to(true)
    end

    describe 'callbacks' do
      it 'runs before_create callback' do
        klass_with_callback = new_class do
          field :name
          before_create { print 'run before_create' }
        end

        expect do
          klass_with_callback.create(name: 'Alex')
        end.to output('run before_create').to_stdout
      end

      it 'runs after_create callback' do
        klass_with_callback = new_class do
          field :name
          after_create { print 'run after_create' }
        end

        expect do
          klass_with_callback.create(name: 'Alex')
        end.to output('run after_create').to_stdout
      end

      it 'runs before_save callback' do
        klass_with_callback = new_class do
          field :name
          before_save { print 'run before_save' }
        end

        expect do
          klass_with_callback.create(name: 'Alex')
        end.to output('run before_save').to_stdout
      end

      it 'runs after_save callbacks' do
        klass_with_callback = new_class do
          field :name
          after_save { print 'run after_save' }
        end

        expect do
          klass_with_callback.create(name: 'Alex')
        end.to output('run after_save').to_stdout
      end

      it 'runs callback specified with method name' do
        klass_with_callback = new_class do
          field :name
          before_create :log_message

          def log_message
            print 'run before_create'
          end
        end

        expect do
          klass_with_callback.create(name: 'Alex')
        end.to output('run before_create').to_stdout
      end
    end

    context 'not unique primary key' do
      context 'composite key' do
        let(:klass_with_composite_key) do
          new_class do
            range :name
          end
        end

        it 'raises RecordNotUnique error' do
          klass_with_composite_key.create(id: '10', name: 'aaa')

          expect {
            klass_with_composite_key.create(id: '10', name: 'aaa')
          }.to raise_error(Dynamoid::Errors::RecordNotUnique)
        end
      end

      context 'simple key' do
        let(:klass_with_simple_key) do
          new_class
        end

        it 'raises RecordNotUnique error' do
          klass_with_simple_key.create(id: '10')

          expect {
            klass_with_simple_key.create(id: '10')
          }.to raise_error(Dynamoid::Errors::RecordNotUnique)
        end
      end
    end

    describe 'timestamps' do
      let(:klass) do
        new_class
      end

      it 'sets created_at and updated_at if Config.timestamps=true', config: { timestamps: true } do
        travel 1.hour do
          time_now = Time.now
          obj = klass.create

          expect(obj.created_at.to_i).to eql(time_now.to_i)
          expect(obj.updated_at.to_i).to eql(time_now.to_i)
        end
      end

      it 'uses provided values of created_at and updated_at if Config.timestamps=true', config: { timestamps: true } do
        travel 1.hour do
          created_at = updated_at = Time.now
          obj = klass.create(created_at: created_at, updated_at: updated_at)

          expect(obj.created_at.to_i).to eql(created_at.to_i)
          expect(obj.updated_at.to_i).to eql(updated_at.to_i)
        end
      end

      it 'does not raise error if Config.timestamps=false', config: { timestamps: false } do
        created_at = updated_at = Time.now
        obj = klass.create

        expect(obj.created_at).to eql(nil)
        expect(obj.updated_at).to eql(nil)
      end
    end
  end

    it 'raises error when tries to save multiple invalid objects' do
      klass = new_class do
        field :city
        validates :city, presence: true
      end
      klass.create_table

      expect do
        klass.create!([{ city: 'Chicago' }, { city: nil }])
      end.to raise_error(Dynamoid::Errors::DocumentNotValid)
    end

  describe '.exist?' do
    it 'checks if there is a document with specified primary key' do
      address = Address.create(city: 'Chicago')

      expect(Address.exists?(address.id)).to be_truthy
      expect(Address.exists?('does-not-exist')).to be_falsey
    end

    it 'supports an array of primary keys' do
      address_1 = Address.create(city: 'Chicago')
      address_2 = Address.create(city: 'New York')
      address_3 = Address.create(city: 'Los Angeles')

      expect(Address.exists?([address_1.id, address_2.id])).to be_truthy
      expect(Address.exists?([address_1.id, 'does-not-exist'])).to be_falsey
    end

    it 'supports hash with conditions' do
      address = Address.create(city: 'Chicago')

      expect(Address.exists?(city: address.city)).to be_truthy
      expect(Address.exists?(city: 'does-not-exist')).to be_falsey
    end

    it 'checks if there any document in table at all if called without argument' do
      Address.create_table(sync: true)
      expect(Address.count).to eq 0

      expect { Address.create }.to change { Address.exists? }.from(false).to(true)
    end
  end

  it 'gets errors courtesy of ActiveModel' do
    address = Address.create(city: 'Chicago')

    expect(address.errors).to be_empty
    expect(address.errors.full_messages).to be_empty
  end

  describe '.update' do
    let(:document_class) do
      new_class do
        field :name

        validates :name, presence: true, length: { minimum: 5 }
      end
    end

    it 'loads and saves document' do
      d = document_class.create(name: 'Document#1')

      expect do
        document_class.update(d.id, name: '[Updated]')
      end.to change { d.reload.name }.from('Document#1').to('[Updated]')
    end

    it 'returns updated document' do
      d = document_class.create(name: 'Document#1')
      d2 = document_class.update(d.id, name: '[Updated]')

      expect(d2).to be_a(document_class)
      expect(d2.name).to eq '[Updated]'
    end

    it 'does not save invalid document' do
      d = document_class.create(name: 'Document#1')
      d2 = nil

      expect do
        d2 = document_class.update(d.id, name: '[Up')
      end.not_to change { d.reload.name }
      expect(d2).not_to be_valid
    end

    it 'accepts range key value if document class declares it' do
      klass = new_class do
        field :name
        range :status
      end

      d = klass.create(status: 'old', name: 'Document#1')
      expect do
        klass.update(d.id, 'old', name: '[Updated]')
      end.to change { d.reload.name }.to('[Updated]')
    end

    it 'dumps range key value to proper format' do
      klass = new_class do
        field :name
        range :activated_on, :date
        field :another_date, :datetime
      end

      d = klass.create(activated_on: '2018-01-14'.to_date, name: 'Document#1')
      expect do
        klass.update(d.id, '2018-01-14'.to_date, name: '[Updated]')
      end.to change { d.reload.name }.to('[Updated]')
    end

    describe 'timestamps' do
      it 'sets updated_at if Config.timestamps=true', config: { timestamps: true } do
        d = document_class.create(name: 'Document#1')

        travel 1.hour do
          time_now = Time.now

          expect {
            document_class.update(d.id, name: '[Updated]')
          }.to change { d.reload.updated_at.to_i }.to(time_now.to_i)
        end
      end

      it 'uses provided value of updated_at if Config.timestamps=true', config: { timestamps: true } do
        d = document_class.create(name: 'Document#1')

        travel 1.hour do
          updated_at = Time.now + 1.hour

          expect {
            document_class.update(d.id, name: '[Updated]', updated_at: updated_at)
          }.to change { d.reload.updated_at.to_i }.to(updated_at.to_i)
        end
      end

      it 'does not raise error if Config.timestamps=false', config: { timestamps: false } do
        d = document_class.create(name: 'Document#1')
        document_class.update(d.id, name: '[Updated]')
        expect(d.reload.name).to eql('[Updated]')
        expect(d.reload.updated_at).to eql(nil)
      end
    end

    describe 'type casting' do
      it 'uses type casted value of sort key to call UpdateItem' do
        document_class_with_range = new_class do
          range :count, :integer
          field :title
        end

        obj = document_class_with_range.create(title: 'Old', count: '100')
        document_class_with_range.update(obj.id, '100', title: 'New')
        expect(obj.reload.title).to eq 'New'
      end

      it 'type casts attributes' do
        klass = new_class do
          field :count, :integer
        end

        obj = klass.create(count: 100)
        obj2 = klass.update(obj.id, count: '101')
        expect(obj2.attributes[:count]).to eql(101)
        expect(raw_attributes(obj2)[:count]).to eql(101)
      end
    end
  end

  describe '.update_fields' do
    let(:document_class) do
      new_class do
        field :title
        field :version, :integer
        field :published_on, :date
      end
    end

    it 'changes field value' do
      obj = document_class.create(title: 'Old title')
      expect do
        document_class.update_fields(obj.id, title: 'New title')
      end.to change { document_class.find(obj.id).title }.from('Old title').to('New title')
    end

    it 'changes field value to nil' do
      obj = document_class.create(title: 'New Document')
      expect do
        document_class.update_fields(obj.id, title: nil)
      end.to change { document_class.find(obj.id).title }.from('New Document').to(nil)
    end

    it 'returns updated document' do
      obj = document_class.create(title: 'Old title')
      result = document_class.update_fields(obj.id, title: 'New title')

      expect(result.id).to eq obj.id
      expect(result.title).to eq 'New title'
    end

    context 'condition specified' do
      it 'updates when model matches conditions' do
        obj = document_class.create(title: 'Old title', version: 1)

        expect {
          document_class.update_fields(obj.id, { title: 'New title' }, if: { version: 1 })
        }.to change { document_class.find(obj.id).title }.to('New title')
      end

      it 'does not update when model does not match conditions' do
        obj = document_class.create(title: 'Old title', version: 1)

        expect {
          result = document_class.update_fields(obj.id, { title: 'New title' }, if: { version: 6 })
        }.not_to change { document_class.find(obj.id).title }
      end

      it 'returns nil when model does not match conditions' do
        obj = document_class.create(title: 'Old title', version: 1)

        result = document_class.update_fields(obj.id, { title: 'New title' }, if: { version: 6 })
        expect(result).to eq nil
      end
    end

    it 'does not create new document if it does not exist yet' do
      document_class.create_table

      expect do
        document_class.update_fields('some-fake-id', title: 'Title')
      end.not_to change { document_class.count }
    end

    it 'accepts range key if it is declared' do
      document_class_with_range = new_class do
        field :title
        range :category
      end

      obj = document_class_with_range.create(category: 'New')

      expect do
        document_class_with_range.update_fields(obj.id, 'New', title: '[Updated]')
      end.to change {
        document_class_with_range.find(obj.id, range_key: 'New').title
      }.to('[Updated]')
    end

    it 'uses dumped value of sort key to call UpdateItem' do
      document_class_with_range = new_class do
        field :title
        range :published_on, :date
      end

      obj = document_class_with_range.create(title: 'Old', published_on: '2018-02-23'.to_date)
      document_class_with_range.update_fields(obj.id, '2018-02-23'.to_date, title: 'New')
      expect(obj.reload.title).to eq 'New'
    end

    it 'dumps attributes values' do
      obj = document_class.create
      document_class.update_fields(obj.id, published_on: '2018-02-23'.to_date)
      attributes = Dynamoid.adapter.get_item(document_class.table_name, obj.id)
      expect(attributes[:published_on]).to eq 17_585
    end

    describe 'timestamps' do
      it 'sets updated_at if Config.timestamps=true', config: { timestamps: true } do
        obj = document_class.create(title: 'Old title')

        travel 1.hour do
          time_now = Time.now

          expect {
            document_class.update_fields(obj.id, title: 'New title')
          }.to change { obj.reload.updated_at.to_i }.to(time_now.to_i)
        end
      end

      it 'uses provided value of updated_at if Config.timestamps=true', config: { timestamps: true } do
        obj = document_class.create(title: 'Old title')

        travel 1.hour do
          updated_at = Time.now + 1.hour

          expect {
            document_class.update_fields(obj.id, title: 'New title', updated_at: updated_at)
          }.to change { obj.reload.updated_at.to_i }.to(updated_at.to_i)
        end
      end

      it 'does not raise error if Config.timestamps=false', config: { timestamps: false } do
        obj = document_class.create(title: 'Old title')
        document_class.update_fields(obj.id, title: 'New title')
        expect(obj.reload.title).to eql('New title')
        expect(obj.reload.updated_at).to eql(nil)
      end
    end

    describe 'type casting' do
      it 'uses casted value of sort key to call UpdateItem' do
        document_class_with_range = new_class do
          range :count, :integer
          field :title
        end

        obj = document_class_with_range.create(title: 'Old', count: '100')
        document_class_with_range.update_fields(obj.id, '100', title: 'New')
        expect(obj.reload.title).to eq 'New'
      end

      it 'type casts attributes' do
        klass = new_class do
          field :count, :integer
        end

        obj = klass.create(count: 100)
        obj2 = klass.update_fields(obj.id, count: '101')
        expect(obj2.attributes[:count]).to eql(101)
        expect(raw_attributes(obj2)[:count]).to eql(101)
      end
    end

    context ':raw field' do
      let(:klass) do
        new_class do
          field :hash, :raw
        end
      end

      it 'works well with hash keys of any type' do
        a = klass.create

        expect {
          klass.update_fields(a.id, hash: { 1 => :b })
        }.not_to raise_error

        expect(klass.find(a.id)[:hash]).to eql('1': 'b')
      end
    end
  end

  describe '.upsert' do
    let(:document_class) do
      new_class do
        field :title
        field :version, :integer
        field :published_on, :date
      end
    end

    it 'changes field value' do
      obj = document_class.create(title: 'Old title')
      expect do
        document_class.upsert(obj.id, title: 'New title')
      end.to change { document_class.find(obj.id).title }.from('Old title').to('New title')
    end

    it 'changes field value to nil' do
      obj = document_class.create(title: 'New Document')
      expect do
        document_class.upsert(obj.id, title: nil)
      end.to change { document_class.find(obj.id).title }.from('New Document').to(nil)
    end

    it 'returns updated document' do
      obj = document_class.create(title: 'Old title')
      result = document_class.upsert(obj.id, title: 'New title')

      expect(result.id).to eq obj.id
      expect(result.title).to eq 'New title'
    end

    context 'conditions specified' do
      it 'updates when model matches conditions' do
        obj = document_class.create(title: 'Old title', version: 1)

        expect {
          document_class.upsert(obj.id, { title: 'New title' }, if: { version: 1 })
        }.to change { document_class.find(obj.id).title }.to('New title')
      end

      it 'does not update when model does not match conditions' do
        obj = document_class.create(title: 'Old title', version: 1)

        expect {
          result = document_class.upsert(obj.id, { title: 'New title' }, if: { version: 6 })
        }.not_to change { document_class.find(obj.id).title }
      end

      it 'returns nil when model does not match conditions' do
        obj = document_class.create(title: 'Old title', version: 1)

        result = document_class.upsert(obj.id, { title: 'New title' }, if: { version: 6 })
        expect(result).to eq nil
      end
    end

    it 'creates new document if it does not exist yet' do
      document_class.create_table

      expect do
        document_class.upsert('not-existed-id', title: 'Title')
      end.to change { document_class.count }

      obj = document_class.find('not-existed-id')
      expect(obj.title).to eq 'Title'
    end

    it 'accepts range key if it is declared' do
      document_class_with_range = new_class do
        field :title
        range :category
      end

      obj = document_class_with_range.create(category: 'New')

      expect do
        document_class_with_range.upsert(obj.id, 'New', title: '[Updated]')
      end.to change {
        document_class_with_range.find(obj.id, range_key: 'New').title
      }.to('[Updated]')
    end

    it 'uses dumped value of sort key to call UpdateItem' do
      document_class_with_range = new_class do
        field :title
        range :published_on, :date
      end

      obj = document_class_with_range.create(title: 'Old', published_on: '2018-02-23'.to_date)
      document_class_with_range.upsert(obj.id, '2018-02-23'.to_date, title: 'New')
      expect(obj.reload.title).to eq 'New'
    end

    it 'dumps attributes values' do
      obj = document_class.create
      document_class.upsert(obj.id, published_on: '2018-02-23'.to_date)
      attributes = Dynamoid.adapter.get_item(document_class.table_name, obj.id)
      expect(attributes[:published_on]).to eq 17_585
    end

    describe 'timestamps' do
      it 'sets updated_at if Config.timestamps=true', config: { timestamps: true } do
        obj = document_class.create(title: 'Old title')

        travel 1.hour do
          time_now = Time.now

          expect {
            document_class.upsert(obj.id, title: 'New title')
          }.to change { obj.reload.updated_at.to_i }.to(time_now.to_i)
        end
      end

      it 'uses provided value of updated_at if Config.timestamps=true', config: { timestamps: true } do
        obj = document_class.create(title: 'Old title')

        travel 1.hour do
          updated_at = Time.now + 1.hour

          expect {
            document_class.upsert(obj.id, title: 'New title', updated_at: updated_at)
          }.to change { obj.reload.updated_at.to_i }.to(updated_at.to_i)
        end
      end

      it 'does not raise error if Config.timestamps=false', config: { timestamps: false } do
        obj = document_class.create(title: 'Old title')
        document_class.upsert(obj.id, title: 'New title')
        expect(obj.reload.title).to eql('New title')
        expect(obj.reload.updated_at).to eql(nil)
      end
    end

    describe 'type casting' do
      it 'uses casted value of sort key to call UpdateItem' do
        document_class_with_range = new_class do
          range :count, :integer
          field :title
        end

        obj = document_class_with_range.create(title: 'Old', count: '100')
        document_class_with_range.upsert(obj.id, '100', title: 'New')
        expect(obj.reload.title).to eq 'New'
      end

      it 'type casts attributes' do
        klass = new_class do
          field :count, :integer
        end

        obj = klass.create(count: 100)
        obj2 = klass.upsert(obj.id, count: '101')
        expect(obj2.attributes[:count]).to eql(101)
        expect(raw_attributes(obj2)[:count]).to eql(101)
      end
    end

    context ':raw field' do
      let(:klass) do
        new_class do
          field :hash, :raw
        end
      end

      it 'works well with hash keys of any type' do
        a = klass.create

        expect {
          klass.upsert(a.id, hash: { 1 => :b })
        }.not_to raise_error

        expect(klass.find(a.id)[:hash]).to eql('1': 'b')
      end
    end
  end

  describe '.inc' do
    let(:document_class) do
      new_class do
        field :links_count, :integer
        field :mentions_count, :integer
      end
    end

    it 'adds specified value' do
      obj = document_class.create!(links_count: 2)

      expect {
        document_class.inc(obj.id, links_count: 5)
      }.to change { document_class.find(obj.id).links_count }.from(2).to(7)
    end

    it 'accepts negative value' do
      obj = document_class.create!(links_count: 10)

      expect {
        document_class.inc(obj.id, links_count: -2)
      }.to change { document_class.find(obj.id).links_count }.from(10).to(8)
    end

    it 'traits nil value as zero' do
      obj = document_class.create!(links_count: nil)

      expect {
        document_class.inc(obj.id, links_count: 5)
      }.to change { document_class.find(obj.id).links_count }.from(nil).to(5)
    end

    it 'supports passing several attributes at once' do
      obj = document_class.create!(links_count: 2, mentions_count: 31)
      document_class.inc(obj.id, links_count: 5, mentions_count: 9)

      expect(document_class.find(obj.id).links_count).to eql(7)
      expect(document_class.find(obj.id).mentions_count).to eql(40)
    end

    it 'accepts sort key if it is declared' do
      class_with_sort_key = new_class do
        range :author_name
        field :links_count, :integer
      end

      obj = class_with_sort_key.create!(author_name: 'Mike', links_count: 2)
      class_with_sort_key.inc(obj.id, 'Mike', links_count: 5)

      expect(obj.reload.links_count).to eql(7)
    end

    it 'uses dumped value of sort key to call UpdateItem' do
      class_with_sort_key = new_class do
        range :published_on, :date
        field :links_count, :integer
      end

      obj = class_with_sort_key.create!(published_on: '2018-10-07'.to_date, links_count: 2)
      class_with_sort_key.inc(obj.id, '2018-10-07'.to_date, links_count: 5)

      expect(obj.reload.links_count).to eql(7)
    end

    describe 'timestamps' do
      it 'does not change updated_at', config: { timestamps: true } do
        obj = document_class.create!
        expect(obj.updated_at).to be_present

        expect {
          document_class.inc(obj.id, links_count: 5)
        }.not_to change { document_class.find(obj.id).updated_at }
      end
    end

    describe 'type casting' do
      it 'uses casted value of sort key to call UpdateItem' do
        class_with_sort_key = new_class do
          range :published_on, :date
          field :links_count, :integer
        end

        obj = class_with_sort_key.create!(published_on: '2018-10-07'.to_date, links_count: 2)
        class_with_sort_key.inc(obj.id, '2018-10-07', links_count: 5)

        expect(obj.reload.links_count).to eql(7)
      end

      it 'type casts attributes' do
        obj = document_class.create!(links_count: 2)

        expect {
          document_class.inc(obj.id, links_count: '5.12345')
        }.to change { document_class.find(obj.id).links_count }.from(2).to(7)
      end
    end
  end

  context '.reload' do
    let(:address) { Address.create }
    let(:message) { Message.create(text: 'Nice, supporting datetime range!', time: Time.now.to_datetime) }
    let(:tweet) { tweet = Tweet.create(tweet_id: 'x', group: 'abc') }

    it 'reflects persisted changes' do
      address.update_attributes(city: 'Chicago')
      expect(address.reload.city).to eq 'Chicago'
    end

    it 'uses a :consistent_read' do
      expect(Tweet).to receive(:find).with(tweet.hash_key, range_key: tweet.range_value, consistent_read: true).and_return(tweet)
      tweet.reload
    end

    it 'works with range key' do
      expect(tweet.reload.group).to eq 'abc'
    end

    it 'uses dumped value of sort key to load document' do
      klass = new_class do
        range :activated_on, :date
        field :name
      end

      obj = klass.create!(activated_on: Date.today, name: 'Old value')
      obj2 = klass.where(id: obj.id, activated_on: obj.activated_on).first
      obj2.update_attributes(name: 'New value')

      expect { obj.reload }.to change {
        obj.name
      }.from('Old value').to('New value')
    end
  end

  it 'has default table options' do
    address = Address.create

    expect(address.id).to_not be_nil
    expect(Address.table_name).to eq 'dynamoid_tests_addresses'
    expect(Address.hash_key).to eq :id
    expect(Address.read_capacity).to eq 100
    expect(Address.write_capacity).to eq 20
    expect(Address.inheritance_field).to eq :type
  end

  it 'follows any table options provided to it' do
    tweet = Tweet.create(group: 12_345)

    expect { tweet.id }.to raise_error(NoMethodError)
    expect(tweet.tweet_id).to_not be_nil
    expect(Tweet.table_name).to eq 'dynamoid_tests_twitters'
    expect(Tweet.hash_key).to eq :tweet_id
    expect(Tweet.read_capacity).to eq 200
    expect(Tweet.write_capacity).to eq 200
  end

  shared_examples 'it has equality testing and hashing' do
    it 'is equal to itself' do
      expect(document).to eq document
    end

    it 'is equal to another document with the same key(s)' do
      expect(document).to eq same
    end

    it 'is not equal to another document with different key(s)' do
      expect(document).to_not eq different
    end

    it 'is not equal to an object that is not a document' do
      expect(document).to_not eq 'test'
    end

    it 'is not equal to nil' do
      expect(document).to_not eq nil
    end

    it 'hashes documents with the keys to the same value' do
      expect(document => 1).to have_key(same)
    end
  end

  context 'without a range key' do
    it_behaves_like 'it has equality testing and hashing' do
      let(:document) { Address.create(id: 123, city: 'Seattle') }
      let(:different) { Address.create(id: 456, city: 'Seattle') }
      let(:same) { Address.new(id: 123, city: 'Boston') }
    end
  end

  context 'with a range key' do
    it_behaves_like 'it has equality testing and hashing' do
      let(:document) { Tweet.create(tweet_id: 'x', group: 'abc', msg: 'foo') }
      let(:different) { Tweet.create(tweet_id: 'y', group: 'abc', msg: 'foo') }
      let(:same) { Tweet.new(tweet_id: 'x', group: 'abc', msg: 'bar') }
    end

    it 'is not equal to another document with the same hash key but a different range value' do
      document = Tweet.create(tweet_id: 'x', group: 'abc')
      different = Tweet.create(tweet_id: 'x', group: 'xyz')

      expect(document).to_not eq different
    end
  end

  context '#count' do
    it 'returns the number of documents in the table' do
      document = Tweet.create(tweet_id: 'x', group: 'abc')
      different = Tweet.create(tweet_id: 'x', group: 'xyz')

      expect(Tweet.count).to eq 2
    end
  end

  describe '.deep_subclasses' do
    it 'returns direct children' do
      expect(Car.deep_subclasses).to eq [Cadillac]
    end

    it 'returns grandchildren too' do
      expect(Vehicle.deep_subclasses).to include(Cadillac)
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

module Spree
  module Admin
    class ElementsController < Spree::Admin::ResourceController
      prepend_view_path('spec/test_views')

      def model_class
        Element
      end
    end
  end
end

describe Spree::Admin::ElementsController, type: :controller do
  stub_authorization!

  # RESOURCE FIXTURE
  before(:all) do
    # Database
    class CreateElements < ActiveRecord::Migration[5.1]
      def change
        create_table(:elements, id: :uuid) do |t|
          t.string :name
          t.integer :position
          t.timestamps null: false
        end
      end
    end
    CreateElements.migrate(:up)

    # Model
    class Element < ActiveRecord::Base
      acts_as_list
      validates :name, presence: true
      before_destroy :check_destroy_constraints

      def check_destroy_constraints
        return unless name == 'undestroyable'
        errors.add :base, "You can't destroy undestroyable things!"
        errors.add :base, "Terrible things might happen."
        throw(:abort)
      end
    end

    # Routes
    Spree::Core::Engine.routes.draw do
      namespace :admin do
        resources :elements do
          post :update_positions, on: :member
        end
      end
    end
  end

  after(:all) do
    # Database
    CreateElements.migrate(:down)
    Object.send(:remove_const, :CreateElements)

    # Model
    Object.send(:remove_const, :Element)

    # Controller
    Spree::Admin.send(:remove_const, :ElementsController)

    # Routes
    Rails.application.reload_routes!
  end

  describe '#update_positions' do
    let(:element_1) { Element.create!(name: 'element 1', position: 1) }
    let(:element_2) { Element.create!(name: 'element 2', position: 2) }

    subject do
      post :update_positions, params: { id: element_1.to_param,
        positions: { element_1.id => '2', element_2.id => '1' }, format: 'js' }
    end

    it 'updates the position of element 1' do
      expect { subject }.to change { element_1.reload.position }.from(1).to(2)
    end

    it 'updates the position of element 2' do
      expect { subject }.to change { element_2.reload.position }.from(2).to(1)
    end

    context 'passing a not persisted item' do
      subject do
        post :update_positions, params: { id: element_1.to_param,
          positions: { element_1.id => '2', element_2.id => '1', 'element' => '3' }, format: 'js' }
      end

      it 'only updates the position of persisted attributes' do
        subject
        expect(Element.all.order('position')).to eq [element_2, element_1]
      end
    end
  end
end

# frozen_string_literal: true

require 'lib/settings'
require 'lib/truncate'

module View
  module Game
    class EntityList < Snabberb::Component
      include Lib::Settings

      needs :round
      needs :entities
      needs :user, default: nil, store: true
      needs :acting_entity, default: nil
      needs :game, store: true

      TOKEN_SIZES = { small: 1.2, medium: 1.4, large: 1.8 }.freeze

      def render
        items = @entities.map.with_index do |entity, index|
          entity_props = {
            key: "entity_#{index}",
            style: {
              float: 'left',
              listStyle: 'none',
              paddingRight: '1rem',
            },
          }

          if @acting_entity == entity
            scroll_to = lambda do |vnode|
              elm = Native(vnode)['elm']
              elm['parentElement']['parentElement'].scrollLeft = elm['offsetLeft'] - 10
            end

            entity_props[:hook] = {
              insert: scroll_to,
              update: ->(_, vnode) { scroll_to.call(vnode) },
            }
          end

          style = entity_props[:style]

          if @acting_entity == entity || @round.can_act?(entity)
            style[:textDecoration] = 'underline'
            style[:fontSize] = '1.1rem'
            style[:fontWeight] = 'bold'
          end

          if index.positive?
            style[:borderLeft] = "#{setting_for(:font)} solid thin"
            style[:paddingLeft] = '1rem'
          end

          children = []
          if entity.corporation? || entity.minor?
            size = TOKEN_SIZES[@game.corporation_size(entity)]
            logo_props = {
              attrs: { src: setting_for(:simple_logos, @game) ? entity.simple_logo : entity.logo },
              style: {
                padding: "#{TOKEN_SIZES[:large] - size}rem 0.4rem 0 0",
                height: "#{size}rem",
              },
            }
            children << h(:img, logo_props)
          end

          owner = " (#{@game.acting_for_entity(entity).name.truncate})" if !entity.player? && entity.owner
          owner = ' (CLOSED)' if entity.closed?
          name = entity.company? ? entity.sym : entity.name
          children << h(:span, "#{name}#{owner}")

          h(:li, entity_props, children)
        end

        div_props = {
          key: 'entity_order',
          attrs: { title: 'Order' },
          style: {
            margin: '1rem 0',
            overflow: 'auto',
          },
        }

        ul_props = {
          key: 'entity_order_container',
          style: {
            width: 'max-content',
            margin: '0',
            padding: '0',
          },
        }

        h(:div, div_props, [
          h(:ul, ul_props, items),
        ])
      end
    end
  end
end

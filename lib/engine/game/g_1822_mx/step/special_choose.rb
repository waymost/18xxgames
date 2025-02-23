# frozen_string_literal: true

require_relative '../../g_1822/step/special_choose'

module Engine
  module Game
    module G1822MX
      module Step
        class SpecialChoose < Engine::Game::G1822::Step::SpecialChoose
          def process_choose_ability(action)
            return unless action.choice == 'close_p16'

            @log << "#{action.entity.owner.name} chooses to close P16"
            @game.close_p16
          end
        end
      end
    end
  end
end

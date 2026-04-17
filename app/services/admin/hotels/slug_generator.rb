module Admin
  module Hotels
    class SlugGenerator < BaseService
      option :name

      def call
        "#{name.to_s.parameterize}-slug"
      end
    end
  end
end

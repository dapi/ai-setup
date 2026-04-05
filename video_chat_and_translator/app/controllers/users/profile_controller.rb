# frozen_string_literal: true

module Users
  class ProfileController < ApplicationController
    def show
      render inertia: "profile/Show", props: {
        translations: I18n.t("auth.profile")
      }
    end
  end
end

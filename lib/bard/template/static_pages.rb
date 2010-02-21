require "bard/template/helper"

# Set up static controller
file "app/controllers/static_controller.rb", <<-END
class StaticController < ApplicationController
  def dispatch
    view_template_path = "/static/"+params[:path].join("/")
    begin
      render view_template_path, :layout => true
    rescue ActionView::MissingTemplate
      begin
        render view_template_path+"/index", :layout => true
      rescue ActionView::MissingTemplate
        raise ActiveRecord::RecordNotFound
      end
    end
  end
end
END

route "map.connect '*path', :controller => 'static', :action => 'dispatch'"
route "map.root :controller => 'static', :action => 'dispatch', :path => ['index']"  

file "app/views/static/index.html.haml", <<-END
%h1 #{project_name}
END

git :add => "."
git :commit => "-m'static controller.'"

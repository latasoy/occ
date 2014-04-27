Occ::Application.routes.draw do
  resources :system_configs


#  match "/signin" => "services#signin"
#  match "/signout" => "services#signout"
  match '/auth/:service/callback' => 'services#create'
  match '/auth/failure' => 'services#failure'
  resources :services, :only => [:index, :create, :destroy] do
    collection do
      get 'signin'
      get 'signout'
      get 'signup'
      post 'newaccount'
      get 'failure'
    end
  end

  resources :users, :only => [:index, :edit, :update, :destroy]

  resources :lists do
    collection do
      get :all
      post :run
      get :tests
    end
    member do
      get :jobs
      post :undelete
    end
  end

  resources :machines, :only => [:index, :destroy] do
    collection do
      get :refresh
      get :all
    end
    member do
      post :status
      post :start
      post :undelete
      post :shutdown
    end
  end

  resources :environments do
    collection do
      get :all
      get :summary
    end
    member do
      get :new_failed
      get :failed
      get :start
      get :stop
      post :undelete
    end

  end

  resources :bugs do
    member do
      post 'undelete'
      post 'new'
    end
    get 'all', :on => :collection
  end

  resources :jobs,:only => [:index, :show, :create ] do
    get 'nxt', :on => :collection
    get 'remove_bug', :on => :member
    get 'pass', :on => :member
  end

  resources :erequests, :only => [:index, :show] do
    collection do
      get 'summary'
      post 'run'
    end
    member do
      get 'stop'
      get 'start'
      get 'failed'
      get 'new_failed'
      get 'undelete'
    end
  end
  root :to => 'environments#summary'

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end


  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id(.:format)))'
end

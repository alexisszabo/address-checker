Rails.application.routes.draw do
  mount Lockup::Engine, at: '/lockup'
  root 'pages#index'
  post 'address_checker/check', to: 'address_checker#check'
end

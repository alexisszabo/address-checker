Rails.application.routes.draw do
  mount Lockup::Engine, at: '/lockup'
  root 'pages#index'
  post 'address_checker/process_addresses', to: 'address_checker#process_addresses'
  post 'address_checker/download_csv', to: 'address_checker#download_csv'
end
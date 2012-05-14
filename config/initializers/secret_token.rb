# Be sure to restart your server when you modify this file.

# Your secret key for verifying the integrity of signed cookies.
# If you change this key, all old signed cookies will become invalid!
# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.
Occ::Application.config.secret_token = ENV['COOKIE_SECRET'] || 'f2b940b804521eb2b85198d59ebce18b2b50461178548444b3fe8a73e2a4d27d1bb49a041770be853df9fbe696384051e79dada968c120698bf8e980314dc56f'

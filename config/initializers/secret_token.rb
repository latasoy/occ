# Be sure to restart your server when you modify this file.

# Your secret key for verifying the integrity of signed cookies.
# If you change this key, all old signed cookies will become invalid!
# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.
Occ::Application.config.secret_token = ENV['OATS_COOKIE_SECRET'] || '3750efb44e808b80649a1ac2f52beafd1fc932a9ef2c5478046c8e74815cc74fb6e8a145e119c8663a6587924c735e391f432df8e0f4ce5d83713f0eba6afe1f' 

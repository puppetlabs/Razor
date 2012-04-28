# Developer README

This file is intended for developers for the Razor project.

## Dependencies

    git clone git@github.com:lynxbat/Razor.git
    cd Razor
    rvm install 1.9.3
    rvm use 1.9.3
    rvm gemset create razor
    rvm --create --rvmrc use ruby-1.9.3-p0@razor
    bundle install

## Testing

    rake spec
    rake spec_html

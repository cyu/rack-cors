# Change Log
All notable changes to this project will be documented in this file.

## 1.0.2 - 2017-10-22
### Fixed
- Automatically allow simple headers when headers are set

## 1.0.1 - 2017-07-18
### Fixed
- Allow lambda origin configuration

## 1.0.0 - 2017-07-15
### Security
- Don't implicitly accept 'null' origins when 'file://' is specified
(https://github.com/cyu/rack-cors/pull/134)
- Ignore '' origins (https://github.com/cyu/rack-cors/issues/139)
- Default credentials option on resources to false
(https://github.com/cyu/rack-cors/issues/95)
- Don't allow credentials option to be true if '*' is specified is origin
(https://github.com/cyu/rack-cors/pull/142)
- Don't reflect Origin header when '*' is specified as origin
(https://github.com/cyu/rack-cors/pull/142)

### Fixed
- Don't respond immediately on non-matching preflight requests instead of
sending them through the app (https://github.com/cyu/rack-cors/pull/106)

## 0.4.1 - 2017-02-01
### Fixed
- Return miss result in X-Rack-CORS instead of incorrectly returning
preflight-hit

## 0.4.0 - 2015-04-15
### Changed
- Don't set HTTP_ORIGIN with HTTP_X_ORIGIN if nil

### Added
- Calculate vary headers for non-CORS resources
- Support custom vary headers for resource
- Support :if option for resource
- Support :any as a possible value for :methods option

### Fixed
- Don't symbolize incoming HTTP request methods

## 0.3.1 - 2014-12-27
### Changed
- Changed the env key to rack.cors to avoid Rack::Lint warnings

## 0.3.0 - 2014-10-19
### Added
- Added support for defining a logger with a Proc
- Return a X-Rack-CORS header when in debug mode detailing how Rack::Cors
processed a request
- Added support for non HTTP/HTTPS origins when just a domain is specified

### Changed
- Changed the log level of the fallback logger to DEBUG
- Print warning when attempting to use :any as an allowed method
- Treat incoming `Origin: null` headers as file://

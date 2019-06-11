module Azure
  module Armrest
    module Insights
      class MetricsService < ArmrestService
        # Creates and returns a new MetricsService object.
        #
        def initialize(armrest_configuration, options = {})
          super(armrest_configuration, 'metrics', 'Microsoft.Insights', options)
        end

        # Return the metric definitions for the given +provider+, +resource_type+,
        # and +resource_name+ for +resource_group+. You may pass a :filter option as well.
        #
        # NOTE: This uses the older REST API. If you want the newer API, use the
        # list_definitions method below.
        #
        # Example:
        #
        #   metrics = Azure::Armrest::Insights::MetricsService.new(conf)
        #
        #   metrics.list('Microsoft.SQL', 'servers', 'myServer/databases/myDB', 'mygroup')
        #   metrics.list('Microsoft.Compute', 'virtualMachines', 'myVm', 'mygroup')
        #
        def list(provider, resource_type, resource_name, resource_group = nil, options = {})
          resource_group ||= configuration.resource_group

          raise ArgumentError, "no resource group provided" unless resource_group

          url = build_url(provider, resource_type, resource_name, resource_group, options)

          response = rest_get(url)

          Azure::Armrest::ArmrestCollection.create_from_response(
            response,
            Azure::Armrest::Insights::MetricDefinition
          )
        end

        # Returns a list metrics for +resource_id+, which can be
        # either a resource object or a plain resource string. You
        # may also provide a +filter+ to limit the results.
        #
        # If no filter expression is defined, the first metric defined
        # for that resource will be returned using the primary aggregation
        # type in the metric defintion over a time period of the last hour.
        #
        #   vms = Azure::Armrest::VirtualMachineService.new(conf)
        #   mts = Azure::Armrest::Insights::MetricService.new(conf)
        #
        #   vm = vms.get('your_vm', 'your_resource_group')


        #   Update By Yanan Xu @11/06/2019 - Filter format is changed for the metrics
        #   start_time = DateTime.parse("2019-06-11 10:10:11")
        #   end_time = DateTime.parse("2019-06-11 11:10:11")
        #   filter = "metricnames=Percentage CPU"
        #   filter << "&timespan=#{start_time.iso8601.gsub(/\+[0-9]*:[0-9]*/, "Z")}/#{end_time.iso8601.gsub(/\+[0-9]*:[0-9]*/, "Z")}"
        #
        #   definitions = mts.list_metrics(vm.id)
        #

        def list_metrics(resource, filter = nil)
          resource_id = resource.respond_to?(:id) ? resource.id : resource
          api_version = '2018-01-01'
          url = File.join(
            configuration.environment.resource_url,
            resource_id,
            'providers/microsoft.insights/metrics'
          )

          url << "?api-version=#{api_version}"
          url << "&#{filter}" if filter

          puts url

          response = rest_get(url)

          Azure::Armrest::ArmrestCollection.create_from_response(response, Azure::Armrest::Insights::Metric)
        end
        # Get a list of metrics definitions for +resource_id+, which can be
        # either a resource object or a plain resource string. You may also
        # provide a +filter+ to limit the results.
        #
        # Note that the output for this method is different than the list
        # method, which uses an older api-version.
        #
        # Example:
        #
        #   vms = Azure::Armrest::VirtualMachineService.new(conf)
        #   mts = Azure::Armrest::Insights::MetricService.new(conf)
        #
        #   vm = vms.get('your_vm', 'your_resource_group')
        #
        #   # With or without filter
        #   definitions = mts.list_definitions(vm.id)
        #   definitions = mts.list_definitions(vm.id, "name.value eq 'Percentage CPU'")
        #
        # Update By Yanan Xu @11/06/2019 - Filter doesn't work for metricDefinitions
        def list_definitions(resource)
          resource_id = resource.respond_to?(:id) ? resource.id : resource
          #version = configuration.provider_default_api_version(provider, 'metricDefinitions')
          version = '2018-01-01'
          url = File.join(
            configuration.environment.resource_url,
            resource_id,
            'providers/microsoft.insights/metricdefinitions'
          )

          url << "?api-version=#{version}"
          # url << "&$filter=#{filter}" if filter

          response = rest_get(url)

          Azure::Armrest::ArmrestCollection.create_from_response(
            response,
            Azure::Armrest::Insights::MetricDefinition
          )
        end

        private

        # Build a URL for the older version of the metrics definitions API.
        #
        def build_url(provider, resource_type, resource_name, resource_group, options)
          url = File.join(
            base_url,
            'resourceGroups',
            resource_group,
            'providers',
            provider,
            resource_type,
            resource_name,
            'metricDefinitions'
          )

          url << "?api-version=2014-04-01"
          url << "&$filter=#{options[:filter]}" if options[:filter]

          url
        end
      end # MetricsService
    end # Insights
  end # Armrest
end # Azure

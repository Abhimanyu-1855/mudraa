module Mudraa
    class CollectionParty
        def self.says
           puts "hello"
           return "world"
        end

        def create_collection_party(create_params)
            collection_party = ShipmentCollectionParty.new(create_params, proforma_mappings)

            unless collection_party.save!
              self.errors.merge!(collection_party.errors)
              return
            end
        
            if self.proforma_mappings.present?
              ShipmentCollectionParty.where(id: proforma_mappings.pluck(:collection_party_id)).update_all(is_tagged: true)
            end
        
            return { id: collection_party.id }
        end

        def update_collection_party(update_params, proforma_mappings, status, performed_by_id, id)
            collection_party = ShipmentCollectionParty.where(id: id).take

            if proforma_mappings.present?
                ShipmentCollectionParty.where(id: proforma_mappings.pluck(:collection_party_id)).update_all(is_tagged: true)
              end

              if status == "locked"
                finance_job_number = collection_party.proforma_mappings.pluck("finance_job_number").compact.uniq.first rescue nil
                bill_response = ShipmentFinanceHelper.create_bill(collection_party, performed_by_id, finance_job_number)
                if bill_response[:error]
                  self.errors.add(:bill_creation_failed_due_to, bill_response[:message])
                  return
                end
                update_params[:finance_job_number] = bill_response['id'].to_s
            end

              unless collection_party.update(update_params)
                self.errors.merge!(collection_party.errors)
                return
              end

              collection_party.audits.create!(get_audit_data(collection_party))

              return { id: collection_party.id }
        end

        def list_collection_party(shipment_mapping, query)
            service_group = []

            shipment_mapping.uniq.each do |mapping|
              shipment_id = mapping[:shipment_id]
              service_provider_id = mapping[:service_provider_id]
              services = query.where(shipment_id: shipment_id, service_provider_id: service_provider_id)
              existing_collection_parties = ShipmentCollectionParty.where(shipment_id: shipment_id, organization_id: service_provider_id, is_active: true)
        
              collection_parties = existing_collection_parties.to_a.select { |ct| ['locked', 'approval_pending', 'coe_approved', 'finance_approved'].include?(ct.status) }
              locked_line_items = collection_parties.present? ? collection_parties.pluck('mappings').to_a.flatten.compact.pluck('buy_line_items').to_a.flatten.count : 0
              collection_parties = get_collection_parties_invoice_total(collection_parties, shipment_id, service_provider_id)
              existing_collection_parties = get_existing_collection_parties_invoice_total(existing_collection_parties, shipment_id, service_provider_id)
              invoice_total = get_invoice_total(collection_parties)
              urgency_invoice_total = get_urgency_invoice_total(collection_parties)
              credit_note_total = get_credit_note_total(collection_parties)
              expense_total_price = invoice_total - urgency_invoice_total
              invoice_currency = collection_parties.first[:invoice_currency] if collection_parties.present?
              service_group.push({ service_provider_id: service_provider_id, services: services, collection_parties: collection_parties, locked_line_items: locked_line_items, shipment_id: shipment_id, invoice_total: invoice_total, invoice_currency: invoice_currency, urgency_invoice_total: urgency_invoice_total, credit_note_total: credit_note_total, expense_total_price: expense_total_price, existing_collection_parties: existing_collection_parties })
            end
        
            data = service_group.as_json.map(&:deep_symbolize_keys)
        end

        def self.get_collection_parties_invoice_total(collection_parties, shipment_id, service_provider_id)
            collection_parties = collection_parties.as_json.map(&:deep_symbolize_keys)

            if collection_parties.present?
              collection_parties.each do |collection_party|
                invoice_total = 0
                invoice_currency = collection_party.to_h[:invoice_currency]
                collection_party[:line_items].to_a.each do |line_item|
                  invoice_total += line_item[:tax_total_price].to_f * line_item[:exchange_rate]
                end
                collection_party[:invoice_total] = invoice_total
                bank_details = ListOrganizationDocuments.run!(filters: {organization_id: collection_party[:organization_id], document_type: "bank_account_details", status: "active"}, pagination_data_required: false, page_limit: GlobalConstants::MAX_SERVICE_OBJECT_DATA_PAGE_LIMIT)[:list]
                collection_party[:bank_status] = bank_details.select{|t| t[:data][:bank_account_number] == collection_party[:bank_details].first[:bank_account_number]}.first.to_h[:verification_status]
              end
            end
            collection_parties
          end

          def self.get_existing_collection_parties_invoice_total(existing_collection_parties, shipment_id, service_provider_id)
            existing_collection_parties = existing_collection_parties.as_json.map(&:deep_symbolize_keys)

            if existing_collection_parties.present?
              existing_collection_parties.each do |existing_collection_party|
                invoice_total = 0
                invoice_currency = existing_collection_party.to_h[:invoice_currency]
                existing_collection_party[:line_items].to_a.each do |line_item|
                  invoice_total += line_item[:tax_total_price].to_f * line_item[:exchange_rate]
                end
                existing_collection_party[:invoice_total] = invoice_total
                bank_details = ListOrganizationDocuments.run!(filters: {organization_id: existing_collection_party[:organization_id], document_type: "bank_account_details", status: "active"}, pagination_data_required: false, page_limit: GlobalConstants::MAX_SERVICE_OBJECT_DATA_PAGE_LIMIT)[:list]
                existing_collection_party[:bank_status] = bank_details.select{|t| t[:data][:bank_account_number] == existing_collection_party[:bank_details].first[:bank_account_number]}.first.to_h[:verification_status]
              end
            end
            existing_collection_parties
          end

          def self.get_invoice_total(collection_parties)
            invoice_total = 0.0
            collection_parties.each do |collection_party|
              invoice_total += collection_party[:invoice_total]
            end
            return invoice_total.round(2)
          end

          def self.get_urgency_invoice_total(collection_parties)
            urgency_invoice_total = 0.0
            collection_parties.each do |collection_party|
              urgency_invoice_total += collection_party[:invoice_total] if collection_party[:urgency_tag].present?
            end
            return urgency_invoice_total.round(2)
          end
        
          def self.get_credit_note_total(collection_parties)
            credit_note_total = 0.0
            collection_parties.each do |collection_party|
              credit_note_total += collection_party[:invoice_total] if collection_party[:invoice_type] == 'credit_note'
            end
            return credit_note_total.round(2)
          end
    end
end
#! /usr/bin/env ruby

require 'date'
require 'json'

@details_example_no = 0
def create_employer_details_example_file(content) 
    path = "enroll/employer/employer_summary/response/example_#{@details_example_no}.json"
    File.write("#{__dir__}/../#{path}", JSON.pretty_generate(content))
    @details_example_no += 1
    "https://raw.githubusercontent.com/dchealthlink/HBX-mobile-app-APIs/master/#{path}"
end

@roster_example_no = 0
def create_employee_roster_example_file(content) 
    path = "enroll/employer/employee_roster/response/example_#{@roster_example_no}.json"
    File.write("#{__dir__}/../#{path}", JSON.pretty_generate(content))
    @roster_example_no += 1
    "https://raw.githubusercontent.com/dchealthlink/HBX-mobile-app-APIs/master/#{path}"
end

class Date
    def on(mday)
        Date.new(year, mon, mday)
    end
end

class PlanYear
    def initialize(start_date, in_open_enrollment, in_pending_renewal)
        @start_date = start_date
        @in_open_enrollment = in_open_enrollment
        @in_pending_renewal = in_pending_renewal
    end

    def in_pending_renewal
        @in_pending_renewal
    end

    def end_of_open_enrollment
        (@start_date << 1).on(13)
    end

    def renewal_deadline
        end_of_open_enrollment - 3
    end

    def earliest_open_enrollment_begins
        @start_date << 2
    end

    def open_enrollment_begins
        earliest_open_enrollment_begins if @in_open_enrollment 
    end

    def renewal_begins
        @start_date << 3
    end

    def plan_year_begins
        @start_date
    end

    def in_renewal_OE
        @in_open_enrollment && (@start_date.month > 6)
    end

    def date_fields
        """\"open_enrollment_begins\" : #{fmt(open_enrollment_begins)},
            \"open_enrollment_ends\" : #{fmt(end_of_open_enrollment)},
            \"plan_year_begins\": #{fmt(plan_year_begins)},
            \"renewal_application_available\": #{fmt(renewal_begins)},
            \"renewal_application_due\": #{fmt(renewal_deadline)}"""
    end
end


def now 
    Date.parse(Time.now.to_s)
end

def plan_starting_in(months, in_open_enrollment = false, in_pending_renewal = false)
    PlanYear.new( (now >> months).on(1), in_open_enrollment, in_pending_renewal)
end

def fmt(dt)
    dt.strftime("%Y-%m-%d") if dt
end

def contact(first: "", last: "", phone: "", mobile: "", email: "", address_1: "", address_2: "", 
    city: "", state: "", zip: "")
    JSON.pretty_generate(
        {
                  first: "#{first}",
                  last: "#{last}",
                  phone: "#{phone}",
                  mobile: "#{mobile}",
                  emails: ["#{email}"],
                  address_1: "#{address_1}",
                  address_2: "#{address_2}",
                  city: "#{city}",
                  state: "#{state}",
                  zip: "#{zip}" 
                }, {indent: "                  "})
end


def staffer(first: "John", last: "Doe", phone: "202-468-6571", mobile: "202-468-6571", email: "john.doe@example.com")
    contact(first: first, last: last, phone: phone, mobile: mobile, email: email)
end

def office(first: "Primary", last: "Office", phone: "202-468-6571", email: "", 
            address_1: "609 H St. NE", address_2: "", city: "Washington", state: "DC", zip: "20001")
    contact(first: first, last: last, phone: phone, email: email, address_1: address_1, address_2:address_2,
        city: city, state: state, zip: zip)
end

def json_section(obj, opts)
    JSON.pretty_generate(obj, opts).gsub(/\{|\}/, '').rstrip
end

def participation(employer_name, total, enrolled, waived, plan_year)

        ee_contrib = (enrolled * 425.00 * ((waived + 1) ** 0.2)).round(2)
        er_contrib = (enrolled * 770.00 * ((waived + 1) ** 0.22)).round(2)

        summary = {
            employer_name: "#{employer_name}",
            employees_total: total,
            employees_enrolled: enrolled,
            employees_waived: waived,
            open_enrollment_begins:        fmt(plan_year.open_enrollment_begins),
            open_enrollment_ends:          fmt(plan_year.end_of_open_enrollment),
            plan_year_begins:              fmt(plan_year.plan_year_begins),
            renewal_in_progress:           plan_year.in_pending_renewal,
            renewal_application_available: fmt(plan_year.renewal_begins),
            renewal_application_due:       fmt(plan_year.renewal_deadline),
            binder_payment_due: nil,
            minimum_participation_required: (total * 2.0 / 3.0).to_i,
            billing_report_date: fmt(now >> 1),
            active_general_agency: (total < 5) ? nil : "Betadyne General Agency, Inc.",
        }

        period_types = ["active"]
        period_types << "renewal" if plan_year.in_renewal_OE

        coverage_options = { health: ["Enrolled", "Waived", "Not Enrolled"], 
                             dental:  ["Enrolled", "Not Enrolled", nil] }

        details = summary.clone
        details[:total_premium] = ee_contrib + er_contrib
        details[:employee_contribution] = ee_contrib
        details[:employer_contribution] = er_contrib
        summary[:employer_details_url] = create_employer_details_example_file(details)
        summary[:employee_roster_url] = create_employee_roster_example_file({
            employer_name: "#{employer_name}",
            roster: 
                ["Mr. Sammy R. Davis Jr.", "Mr. Frank S. Sinatra III", "Mr. Dean D. Martin Sr."].each_with_index.map do |e, index|
                    
                    pfx, first, mid, last, sfx = e.split
                    { 
                        id: @roster_example_no * 100 + index,
                        enrollments: 
                            Hash[period_types.map do |period_type|
                                [ period_type, 
                                coverage_options.map do |coverage_kind, stati|
                                    status = stati[index]
                                    {
                                        coverage_kind: coverage_kind,
                                        period_type: period_type,
                                        status: status
                                    } if status
                                end.compact ]
                            end ],
                        # removed: name_prefix: pfx,
                        first_name: first,
                        middle_name: mid,
                        last_name: last,
                        name_suffix: sfx
                    }
                end
            })

        json_section(summary, {indent: "            "})       
end


min_months_to_renew = if now.mday > 10 then 2 else 1 end
min_months_to_enroll = if now.mday > 13 then 2 else 1 end

in_open_enrollment = plan_starting_in(2, true)
late_open_enrollment = plan_starting_in(min_months_to_enroll, true)
in_renewal = plan_starting_in(2, false, true)
early_renewal  = plan_starting_in(3, false, true)
late_to_renewal = plan_starting_in(min_months_to_renew, false, true)

text = """
 {
    \"broker_agency\" : \"Bob's Brokers\",
    
    \"broker_clients\": [
            {
            #{participation("Courageous Consulting, LLC", 30, 5, 0, late_open_enrollment)},
            
            \"contact_info\": [
                #{staffer(first: "Bob", phone: "", email: "bob@courageous-consulting.com")},
                #{office(address_1: "1600 Pennsylvania Avenue")}
            ]
            },
            {
            #{participation("National Network to End Domestic Abuse", 41, 10, 5, in_open_enrollment)},
            \"contact_info\": [
                #{staffer(first: "Jane", phone: "202-555-0000", email: "contact@endabuse.org")},
                #{office(address_1: "1600 New Hampshire Avenue")}
            ]
            },
            {
            #{participation("District Yoga", 30, 20, 3, in_open_enrollment)},
            \"contact_info\": [      
                #{staffer(first: "Priya", last: "Chandragupta", email: "contact@districtyoga.com")},
                #{office(address_1: "1600 New York Avenue", phone: "202-555-0212")}
            ]
            },
            {
            #{participation("DC Cupcakes", 50, 40, 7, plan_starting_in(5))},
            \"contact_info\": [      
                #{staffer(first: "Emile", last: "Della Noce", email: "contact@dccupcakes.com")},
                #{office(address_1: "1600 Rhode Island Avenue", phone: "202-555-0313")}
            ]
            },
            {
            #{participation("OPEN Art Studio", 30, 20, 3, late_open_enrollment)},
            \"contact_info\": [      
                #{staffer(first: "Yona", last: "Mendelssohn", email: "yona@openart.org")},
                #{staffer(first: "Noam", last: "Mendelssohn", email: "noam@openart.org")},
                #{office(address_1: "1600 Arizona Avenue", phone: "202-555-0414")}
            ]
            },
            {
            #{participation("Best Brau Brewing Company", 30, 20, 6, in_renewal)},
            \"contact_info\": [      
                #{staffer(first: "Heinrich", last: "Biergarten", email: "heini@bestbrau.com")},
                #{staffer(first: "Ulrich", last: "Suufersohn", email: "ueli@bestbrau.com")},
                #{office(address_1: "1600 Nebraska Avenue", phone: "202-555-0515")},
                #{office(first: "Branch", address_1: "6600 Nebraska Avenue")}
            ]
            },
            {
            #{participation("Bistrot Du Monde", 33, 20, 4, late_to_renewal)},
            \"contact_info\": [      
                #{staffer(first: "Claudette", last: "Noire", email: "cnoire@dumonde.com")},
                #{staffer(first: "Aloise", last: "Rouge", email: "arouge@dumonde.com")},
                #{office(address_1: "1600 Louisiana Avenue", phone: "202-555-0005")}
            ]
            },  
            {
            #{participation("Bistrot Du Bois", 15, 7, 7, early_renewal)},
            \"contact_info\": [      
                #{staffer(first: "Claudette", last: "Blanc", email: "cblan@dubois.com")},
                #{staffer(first: "Aloise", last: "Vert", email: "avert@dubois.com")},
                #{office(address_1: "1600 Maine Avenue", phone: "202-555-0006")}
            ]
            },
            {
            #{participation("Strategy & Tactics Game Shop", 6, 2, 2, plan_starting_in(8))},
            \"contact_info\": [      
                #{staffer(first: "Maria Susanna", last: "Ludador", email: "contact@stgames.com")},
                #{office(address_1: "1600 Georgia Avenue", phone: "202-555-0007")}
            ]
            },
            {
            #{participation("Portia's Tea Bar", 12, 9, 2, plan_starting_in(7))},
            \"contact_info\": [      
                #{staffer(first: "Portia", last: "Binglesworth-Inglesham", email: "portia@helloportia.com")},
                #{office(address_1: "1600 Alabama Avenue", phone: "202-555-0008")},
                #{office(first: "Branch", address_1: "1600 Utah Avenue", address_2: "Suite 500", phone: "202-555-0009")}
            ]
            },
            {
            #{participation("J. Grigory Food Trucks & Fine Comestibles", 66, 50, 0, plan_starting_in(6))},
            \"contact_info\": [
                #{staffer(first: "Joe", last: "Grigory", email: "jgrigory@jgrigory.com")},
                #{office(address_1: "1600 North Carolina Avenue", phone: "202-555-0009")}
            ]
            }
    ]
}
"""

print text




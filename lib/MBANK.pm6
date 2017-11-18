use v6;

use Bank;
unit module MBANK;

class  MBANK::MBANK does Bank::currency-value  {

    use IO::String;
    use CSV::Parser;
    use HTTP::Tinyish;

    has %.valutes is rw;
    has %.res;
    has Str $.currency;
    has Str $.table;
    has Str $.url is rw = qqww{https://www.mbank.pl/ajax/currency/getCSV/};
    has Str $.date;
    has Bool $.dwn_state is rw = False;
    has Int $.http_timeout;

    method new(Str $currency_?, Int $http_timeout_=5,  Str $date_=Date.today.gist.Str, Int :$http_timeout=$http_timeout_, Str :$currency = $currency_, Str :$date=$date_) {
        self.bless(:$currency, :$date, :$http_timeout);
    }
    method TWEAK() {
        if $.date eq Date.today.gist.Str {
            $.url =  $.url ~ "?id=0" ~ "&date=$.date&lang=en";
        }
        else {
            $.url =  $.url ~ "?id=1" ~ "&date=$.date&lang=en";
        }

    }

    method set_url (Str $new_url) {
        $.url = $new_url;
    }

    method download_data{

        my $http = HTTP::Tinyish.new(agent => 'Mozilla/5.0', timeout=>$.http_timeout);
        %.res = $http.get($.url);
        if %.res<status>.Int == 200 {
            $.dwn_state = True;
        }

        self
    }

    method make_data {

        if  $.dwn_state == False {
            return self
        }

        my $Strio_buffer = IO::String.new(buffer=>$.res<content>);

        #Seek to third line => Where data lines start.
        $_ = $Strio_buffer.get();
        my $line_date_ = $Strio_buffer.get();

        if $line_date_ ~~ /(\d\d\d\d\-\d\d\-\d\d)/ {
            %.valutes{"date"} = $0.Str;
        }


        my $csv_parser = CSV::Parser.new(file_handle=>$Strio_buffer,
                                         contains_header_row => True,
                                         field_separator=>';');
        my %csv_data;

        $.dwn_state = False;

        while %csv_data = %($csv_parser.get_line()) {


            if %csv_data<Currency> eq $.currency {
                %.valutes{"code"} = $.currency;
                %.valutes{"full_name"} = %csv_data{"Name"};
                %.valutes{"ask"} = %csv_data{"Sell"}.Rat/%csv_data{"Reference number"}.Rat;
                %.valutes{"bid"} = %csv_data{"Buy"}.Rat/%csv_data{"Reference number"}.Rat;
                $.dwn_state = True;

                last;
            } else {

            }

        }

        self;
    }

}

# install public keys if missing

class Bard::Provision::AuthorizedKeys < Bard::Provision
  def call
    print "Authorized Keys:"

    KEYS.each do |search_text, full_key|
      provision_server.run! <<~BASH #, quiet: true
        file=~/.ssh/authorized_keys
        if ! grep -F -q "#{search_text}" $file; then
          echo "#{full_key}" >> $file
        fi
      BASH
    end

    puts " ✓"
  end

  KEYS = {
    "micah@haku" => "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDAH235mtpxPQucd0bIgdufo1bR3By2+a+NPHiZS1P7SpI73evN9+hY7ri+gLscPLRWeoy1ig/TbyfN1AqJmfqIaskZdYOdcEQdOum4AwDMY5L6OAq2o5NER047RqDxE6Pjm2nfRVVw2Dz38eeco+ouchCI+sY5pJL/wEZItrCpPjKvwo56uln1rL6Smd4Kh98ZBKTGL8xKs95rNmFdBCCq4eUE28JDgkJAiLDZ/4u2LNrgEr7/brkUieZjaZ4BacBi8EQvyvMWmZ0g2MoG+Ptxn/3K2nd1QqdhfINqHBVCi8UbkP08B0Msif/7Dycuxd7DU9cVZ3RgnhLtbIsQ8HaYVj5yCKB6CuX3lv3H4YKBghBC/TnJD5Nq5xcSYTW0BKKrusCb/OoOk5AUV+BGM1+R70fno8reVEBUlZDkWapHxmqgNnf1byL7Aol/L5SWgyfSLT6b5FjI6g/U+dhaecYY9T9g/GWo+JiwZktc094O0ujlQHoibMY2M0csVfvO9Oc= micah@haku",
    "gubs@Theia.local" => "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEApJh0E8ZlaLbMUWGvryAhEBRnnI519ZKz586vdQTuIPlDb9xhe5m3Ys8Fk9LKqJUQNxBV6qCGOXNgNdWySkk2ChmmgDnPfr7/31ZuOAASFbUY0PtaDXUsMVvs1Uu2VhtRU9gSduGonEHG7iBpAuBI23CxU4yPS6o3pv7L9xwnmULes5F9S4/nDvPig15h9byInyHOLDV0XjHFS+2OlSWO/xC8uqH5CdlxXFAmPQ0R69qmILl0rcTPyNMLJGcJGUzb/LMRJX/RDyTpZeJPjH4V+zksQ/4YQ3LWvLrlZL6QLuM285ve4mQa3vBY4WMqNlp4Ig3ZCFOpMKmpvTn7pFUmKw== gubs@Theia.local",
  }
end



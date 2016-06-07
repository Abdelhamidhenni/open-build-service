FactoryGirl.define do
  factory :package do
    sequence(:name) { |n| "package_#{n}" }
    factory :package_with_file do
      after(:create) do |package|
        # NOTE: Enable global write through when writing new VCR cassetes.
        # ensure the backend knows the project
        Suse::Backend.put("/source/#{CGI.escape(package.project.name)}/_meta", package.project.to_axml)
        Suse::Backend.put("/source/#{CGI.escape(package.project.name)}/#{CGI.escape(package.name)}/_meta", package.to_axml)
        Suse::Backend.put("/source/#{CGI.escape(package.project.name)}/#{CGI.escape(package.name)}/somefile.txt", Faker::Lorem.paragraph)
      end
    end
  end
end

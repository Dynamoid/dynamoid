# Dirty API

Dynamoid supports Dirty API which is equivalent to [Rails 5.2
`ActiveModel::Dirty`](https://api.rubyonrails.org/v5.2/classes/ActiveModel/Dirty.html).
There is only one limitation - change in place of field isn't detected
automatically.

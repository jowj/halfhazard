#  model documentation

## users
- uid (firebase auth provides this)
- displayName (optional)
- email (from auth)
- groupIds (array of refs)
- createdAt
- lastActive

## groups
- id
- name
- memberIds (array of user uids)
- createdBy (user uid)
- createdAt
- settings (object for future-proofing)

## expenses
- id
- amount
- title
- description (optional)
- groupId (single ref)
- createdBy (user uid)
- createdAt
- splitType (equal, custom, etc)
- splits (object mapping uid -> amount)

## Settings object
turns out we need this, no idea what'll be here

## SplitType
A custom object where I guess we hide all the math for particular splits. For now only implement equal splitting lol.

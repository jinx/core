package family;

public class Address
{
    private String street1;
  
    private String street2;
  
    private String city;
  
    private String state;
  
    private String postalCode;

    public Address()
    {
    }

    public String getStreet1()
    {
        return street1;
    }

    public void setStreet1(String value)
    {
        this.street1 = value;
    }

    public String getStreet2()
    {
        return street2;
    }

    public void setStreet2(String value)
    {
        this.street2 = value;
    }

    public String getCity()
    {
        return city;
    }

    public void setCity(String value)
    {
        this.city = value;
    }

    public String getState()
    {
        return state;
    }

    public void setState(String value)
    {
        this.state = value;
    }

    public String getPostalCode()
    {
        return postalCode;
    }

    public void setPostalCode(String value)
    {
        this.postalCode = value;
    }
}

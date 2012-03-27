package family;

import java.util.Collection;
import java.util.ArrayList;

public class Parent extends Person
{
    private Parent spouse;
    
    private String ssn;

    private Collection<Child> children;

    public Parent()
    {
        children = new ArrayList<Child>();
    }

    public String getSSN()
    {
        return ssn;
    }

    public void setSSN(String value)
    {
        this.ssn = value;
    }

    public Parent getSpouse()
    {
        return spouse;
    }

    public void setSpouse(Parent spouse)
    {
        this.spouse = spouse;
    }

    public Collection<Child> getChildren()
    {
        return children;
    }

    public void setChildren(Collection<Child> children)
    {
        this.children = children;
    }
}
